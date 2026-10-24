import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';
import '../../services/bill_ocr_service.dart';
import '../../services/bill_scan_analyzer.dart';
import '../../services/voice_number.dart';
import '../../shared/widgets/dialogs.dart';
import '../bills/scan_review_screen.dart';
import '../../state/app_state.dart';
import 'assistant_avatar.dart';
import 'assistant_models.dart';
import 'assistant_tools.dart';
import 'cloud_brain.dart';

/// Chat with the assistant: ask in your own words (typed or spoken), send a
/// bill photo, or tap a suggestion. It answers from your data and can act.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.initialMessage});

  /// Sent straight away (e.g. from a Home suggestion).
  final String? initialMessage;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  late final CloudBrain _brain;
  bool _thinking = false;

  /// Bumped by Stop, so a late answer to a cancelled question is dropped.
  int _generation = 0;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _brain = CloudBrain(AssistantTools(state));
    _brain.chatLanguage = state.chatLanguage;
    _messages.addAll(state.loadChat());
    if (_messages.isEmpty) _messages.add(ChatMessage(fromUser: false, text: _welcome()));
    // Open at the latest message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
    final first = widget.initialMessage;
    if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => _send(first));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _welcome() {
    final state = context.read<AppState>();
    final b = state.bills.firstOrNull;
    final hello = 'Assalam o alaikum! I\'m your Bijli Hisaab assistant.'.tr;
    if (b == null) return '$hello ${'Ask me anything about your electricity bill, or tell me what to do.'.tr}';
    return '$hello ${'Your {0} bill is {1}. Ask me anything, or tell me what to do.'.trf({
      '0': Fmt.month(b.monthDate),
      '1': b.amount > 0 ? Fmt.rs(b.amount) : '{0} units'.trf({'0': b.units}),
    })}';
  }

  List<String> get _suggestions {
    final state = context.read<AppState>();
    return [
      'Scan my bill'.tr,
      if (state.bills.isNotEmpty) 'When is my bill due?'.tr,
      if (state.bills.isNotEmpty) 'What will my next bill be?'.tr,
      if (state.canFetchOnlineBill) 'Check for a new bill'.tr,
      'How do I get protected rates?'.tr,
      'Why is my bill so high?'.tr,
      '250 units kitna bill?',
      'Add another meter'.tr,
      'Open History'.tr,
    ];
  }

  static final _scanWords = RegExp(
    r'^\s*(scan|scanner|اسکین)\b|\b(scan|اسکین)\s*(my|mera|the|kro|karo|kar|bill|بل)|\b(bill|بل)\s*(scan|اسکین)',
    caseSensitive: false,
  );

  Future<void> _send(String text, {String? imagePath}) async {
    final t = text.trim();
    if ((t.isEmpty && imagePath == null) || _thinking) return;
    // "Scan my bill" opens the scanner right here in the chat.
    if (imagePath == null && _scanWords.hasMatch(t) && t.length < 40 && !t.contains('?') && !t.contains('؟')) {
      _input.clear();
      await _capture('scan');
      return;
    }
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: t, imagePath: imagePath));
      _thinking = true;
    });
    _toBottom();
    final gen = _generation;
    try {
      final r = await _brain.respond(t, imagePath: imagePath, history: _messages.sublist(0, _messages.length - 1));
      if (!mounted || gen != _generation) return;
      setState(() => _messages.add(ChatMessage(fromUser: false, text: r.text, actions: r.actions)));
    } catch (e) {
      if (mounted) {
        setState(
          () => _messages.add(ChatMessage(fromUser: false, text: 'Sorry, something went wrong. Please try again.'.tr)),
        );
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _thinking = false);
      _toBottom();
    }
  }

  Future<void> _runAction(ReplyAction a) async {
    final follow = await a.run();
    if (follow != null && mounted) {
      setState(() => _messages.add(ChatMessage(fromUser: false, text: follow)));
      _toBottom();
    }
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner_rounded),
              title: Text('Scan my bill'.tr),
              subtitle: Text('Finds the edges, crops and reads it — then save in one tap'.tr),
              onTap: () => Navigator.pop(ctx, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text('Take a photo of the bill'.tr),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text('Choose from gallery'.tr),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _capture(choice);
  }

  /// Opens the scanner / camera / gallery and reads the bill in the chat.
  Future<void> _capture(String choice) async {
    final state = context.read<AppState>();
    final ocr = BillOcrService();
    List<String> images;
    try {
      if (choice == 'scan') {
        try {
          images = await ocr.capture(state.smartScanner ? CaptureSource.smartScanner : CaptureSource.camera);
        } on SmartScannerUnavailable {
          images = await ocr.capture(CaptureSource.camera);
        }
      } else {
        final img = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2200,
        );
        if (img == null) return;
        images = [img.path];
      }
    } on ScanCancelled {
      return;
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the camera: {0}'.trf({'0': e}));
      return;
    }
    if (images.isEmpty || !mounted) return;
    final question = _input.text.trim();
    _input.clear();
    await _readBill(images, question);
  }

  /// Reads a scanned bill right here and offers to save it.
  Future<void> _readBill(List<String> images, String question) async {
    final state = context.read<AppState>();
    setState(() {
      _messages.add(
        ChatMessage(fromUser: true, text: question.isEmpty ? 'Here is my bill.'.tr : question, imagePath: images.first),
      );
      _thinking = true;
    });
    _toBottom();
    try {
      final result = await BillOcrService().read(
        images,
        estimateAmount: state.estimateBillFor,
        expectedCompany: state.activeMeter?.disco,
      );
      if (!mounted) return;
      setState(() => _messages.add(_billCard(result)));
      // A question with the photo also goes to the assistant.
      if (question.isNotEmpty) {
        final r = await _brain.respond(question, imagePath: images.first, history: _messages);
        if (mounted) setState(() => _messages.add(ChatMessage(fromUser: false, text: r.text, actions: r.actions)));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _messages.add(
            ChatMessage(
              fromUser: false,
              text: 'I could not read that bill. Try again in good light, with the whole bill in view.'.tr,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  ReplyAction _reviewAction(String label, BillScanResult result) => ReplyAction(label, () async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanReviewScreen(initial: result)));
    return null;
  });

  ChatMessage _billCard(BillScanResult result) {
    final state = context.read<AppState>();
    final a = result.analysis;
    final month = a.month?.value;
    final units = a.units?.value;
    String mark(FieldConfidence? c) => c == FieldConfidence.low ? '  ⚠' : '';
    final lines = <String>[
      if (a.disco != null) '${'Company'.tr}: ${a.disco}',
      if (month != null) '${'Bill month'.tr}: ${Fmt.monthKeyLabel(month)}${mark(a.month?.confidence)}',
      if (units != null) '${'Units'.tr}: $units${mark(a.units?.confidence)}',
      if (a.amount?.value != null) '${'Amount'.tr}: ${Fmt.rs(a.amount!.value)}${mark(a.amount?.confidence)}',
      if (a.dueDate?.value != null) '${'Due date'.tr}: ${Fmt.day(a.dueDate!.value)}${mark(a.dueDate?.confidence)}',
      if (a.presentReading?.value != null) '${'Meter reading'.tr}: ${Fmt.whole(a.presentReading!.value)}',
    ];
    if (month == null || units == null) {
      return ChatMessage(
        fromUser: false,
        text: lines.isEmpty
            ? 'I could not read the bill clearly. Try the scan again with the whole bill flat and in good light.'.tr
            : '${'I could only read part of it:'.tr}\n${lines.join('\n')}',
        actions: [_reviewAction('Check & fill in'.tr, result)],
      );
    }
    final meter = state.activeMeter;
    final otherCompany = a.disco != null && meter != null && a.disco != meter.disco;
    final warn = [
      if (otherCompany)
        'This looks like a {0} bill, but {1} is set to {2}.'.trf({'0': a.disco!, '1': meter.name, '2': meter.disco}),
      if (lines.any((l) => l.endsWith('⚠'))) 'Values marked ⚠ may be misread — check them.'.tr,
    ];
    return ChatMessage(
      fromUser: false,
      text: '${'Here is what I read:'.tr}\n${lines.join('\n')}${warn.isEmpty ? '' : '\n\n${warn.join('\n')}'}',
      actions: [
        ReplyAction('Save this bill'.tr, () async {
          final meterId = state.activeMeter?.id;
          if (meterId == null) return 'Set up your meter first.'.tr;
          final existing = state.bills.where((b) => b.month == month).firstOrNull;
          await state.saveBill(
            Bill(
              id: existing?.id,
              meterId: meterId,
              month: month,
              units: units,
              amount: a.amount?.value ?? existing?.amount ?? 0,
              dueDate: a.dueDate?.value ?? existing?.dueDate,
              presentReading: a.presentReading?.value ?? existing?.presentReading,
              source: 'scan',
              createdAt: existing?.createdAt ?? DateTime.now(),
            ),
            original: existing,
          );
          await state.logBillScanned([
            if (a.units != null) 'units',
            if (a.amount != null) 'amount',
            if (a.dueDate != null) 'due',
            if (a.month != null) 'month',
          ]);
          final remind = a.dueDate?.value == null ? '' : 'I will remind you before the due date.'.tr;
          return (existing == null ? 'Saved your {0} bill. {1}' : 'Updated your {0} bill. {1}').trf({
            '0': Fmt.monthKeyLabel(month),
            '1': remind,
          });
        }),
        _reviewAction('Check & edit'.tr, result),
      ],
    );
  }

  Future<void> _voice() async {
    if (_listening) {
      await VoiceNumber.stop();
      return;
    }
    setState(() => _listening = true);
    final words = await VoiceNumber.listenWords(
      localeId: (_brain.chatLanguage ?? L10n.language) == 'ur' ? 'ur_PK' : 'en_US',
      onPartial: (w) {
        if (mounted) setState(() => _input.text = w);
      },
    );
    if (!mounted) return;
    setState(() => _listening = false);
    if (words != null) await _send(words);
  }

  /// Scrolls to the newest message and saves the chat.
  void _toBottom() {
    if (!mounted) return;
    context.read<AppState>().saveChat(_messages);
    context.read<AppState>().setChatLanguage(_brain.chatLanguage);
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  void _clear() {
    context.read<AppState>().clearChat();
    _clearView();
  }

  void _clearView() => setState(() {
    _messages
      ..clear()
      ..add(ChatMessage(fromUser: false, text: _welcome()));
  });

  void _toggleChatLanguage() {
    final now = _brain.chatLanguage ?? L10n.language;
    final next = now == 'ur' ? 'en' : 'ur';
    setState(() {
      _brain.chatLanguage = next;
      _messages.add(
        ChatMessage(
          fromUser: false,
          text: next == 'ur' ? 'ٹھیک ہے، اب میں اردو میں بات کروں گا۔' : 'Okay, I\'ll talk in English now.',
        ),
      );
    });
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final typing = _input.text.trim().isNotEmpty;
    final chatUrdu = (_brain.chatLanguage ?? L10n.language) == 'ur';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const AssistantAvatar(size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assistant'.tr, style: theme.textTheme.titleMedium),
                  Text(
                    CloudBrain.configured ? 'Smart AI · can act in the app'.tr : 'Built-in · works offline'.tr,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Chat language (the app's language stays as it is).
          TextButton(
            onPressed: _toggleChatLanguage,
            child: Text(chatUrdu ? 'اردو' : 'EN', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: 'New chat'.tr,
            onPressed: _thinking ? null : _clear,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _messages.length) return _Bubble(_messages[i], onAction: _runAction);
                return _Typing(
                  status: _brain.status,
                  onStop: () => setState(() {
                    _generation++;
                    _thinking = false;
                    _messages.add(ChatMessage(fromUser: false, text: 'Stopped.'.tr));
                    _toBottom();
                  }),
                );
              },
            ),
          ),
          // Suggestions: a quiet row that hides while you type.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: typing || _thinking
                ? const SizedBox(width: double.infinity)
                : SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final s in _suggestions)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ActionChip(
                              label: Text(s),
                              onPressed: () => _send(s),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Scan or send a bill'.tr,
                    onPressed: _thinking ? null : _attach,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border.all(color: _listening ? AppColors.amber : p.border, width: _listening ? 2 : 1),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _send,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: _listening ? 'Listening… speak now'.tr : 'Ask or tell me what to do…'.tr,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 12),
                              ),
                            ),
                          ),
                          if (!typing)
                            IconButton(
                              tooltip: 'Scan my bill'.tr,
                              onPressed: _thinking ? null : () => _capture('scan'),
                              icon: Icon(Icons.document_scanner_outlined, color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // One button: mic while empty, send once you type.
                  _MicSendButton(
                    send: typing,
                    listening: _listening,
                    busy: _thinking,
                    onSend: () => _send(_input.text),
                    onMic: _voice,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mic ↔ send, with a spin-and-scale swap. Pulses while listening.
class _MicSendButton extends StatefulWidget {
  const _MicSendButton({
    required this.send,
    required this.listening,
    required this.busy,
    required this.onSend,
    required this.onMic,
  });

  final bool send;
  final bool listening;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  State<_MicSendButton> createState() => _MicSendButtonState();
}

class _MicSendButtonState extends State<_MicSendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _MicSendButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.send
        ? const Icon(Icons.arrow_upward_rounded, key: ValueKey('send'))
        : Icon(
            widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
            key: ValueKey(widget.listening ? 'stop' : 'mic'),
          );
    final color = widget.listening ? Colors.redAccent : AppColors.amber;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (widget.listening)
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 6 + 12 * _pulse.value,
                spreadRadius: 2 * _pulse.value,
              ),
          ],
        ),
        child: child,
      ),
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.busy && widget.send ? null : (widget.send ? widget.onSend : widget.onMic),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: IconTheme(
                  key: icon.key,
                  data: IconThemeData(color: widget.listening ? Colors.white : AppColors.navy, size: 26),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.onAction});

  final ChatMessage m;
  final Future<void> Function(ReplyAction) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final mine = m.fromUser;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.82 : 0.74)),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? AppColors.amber.withValues(alpha: p.isDark ? 0.25 : 0.35) : p.surface,
              border: mine ? null : Border.all(color: p.border),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(mine ? 18 : 4),
                bottomEnd: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.imagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(m.imagePath!),
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 56,
                          width: 160,
                          alignment: Alignment.center,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                          child: const Icon(Icons.receipt_long_rounded),
                        ),
                      ),
                    ),
                  ),
                if (m.text.isNotEmpty) SelectableText(m.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
              ],
            ),
          ),
          if (m.actions.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in m.actions)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => onAction(a),
                    child: Text(a.label),
                  ),
              ],
            ),
        ],
      ),
    );
    final time = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        Fmt.clock(m.time.hour, m.time.minute),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
    if (mine) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [bubble, time]),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.only(top: 6), child: AssistantAvatar(size: 28, spark: false)),
          const SizedBox(width: 6),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bubble, time]),
          ),
        ],
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing({required this.status, required this.onStop});

  final ValueListenable<String?> status;
  final VoidCallback onStop;

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.3 + 0.7 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ValueListenableBuilder<String?>(
                valueListenable: widget.status,
                builder: (_, s, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    s ?? 'Thinking…'.tr,
                    key: ValueKey(s),
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onStop,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text('Stop'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
