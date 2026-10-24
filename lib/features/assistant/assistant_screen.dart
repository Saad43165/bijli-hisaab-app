import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
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

  /// Microphone level while listening, 0–1 (drives the waveform).
  final _level = ValueNotifier<double>(0);
  DateTime? _listenStart;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _brain = CloudBrain(AssistantTools(state));
    _brain.chatLanguage = state.chatLanguage;
    _messages.addAll(state.loadChat());
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
    _level.dispose();
    if (_listening) VoiceNumber.cancel();
    super.dispose();
  }

  bool get _chatUrdu => (_brain.chatLanguage ?? L10n.language) == 'ur';

  /// The questions people ask most, answered from their own data.
  List<String> get _suggestions => _chatUrdu
      ? const [
          'میرا بل کتنا آئے گا؟',
          'کتنے یونٹ باقی ہیں؟',
          'کیا میں محفوظ صارف ہوں؟',
          'سب سے زیادہ بجلی کون استعمال کرتا ہے؟',
          'بجلی کیسے بچاؤں؟',
        ]
      : const [
          'How much will my bill be?',
          'How many units can I still use?',
          'Am I protected?',
          'Biggest power user?',
          'How to save?',
        ];

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
      setState(() => _messages.add(ChatMessage(fromUser: false, text: r.text, actions: r.actions, source: r.source)));
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
      setState(() => _messages.add(ChatMessage(fromUser: false, text: follow, source: ReplySource.data)));
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
        if (mounted) {
          setState(() => _messages.add(ChatMessage(fromUser: false, text: r.text, actions: r.actions, source: r.source)));
        }
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
        source: ReplySource.data,
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
      source: ReplySource.data,
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
    HapticFeedback.lightImpact();
    _level.value = 0;
    setState(() {
      _listening = true;
      _listenStart = DateTime.now();
      _input.clear();
    });
    final words = await VoiceNumber.listenWords(
      localeId: _chatUrdu ? 'ur_PK' : 'en_US',
      onPartial: (w) {
        if (mounted) setState(() => _input.text = w);
      },
      onLevel: (v) => _level.value = v,
    );
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _listening = false);
    final problem = VoiceNumber.lastProblem;
    if (problem != null) {
      showSnack(
        context,
        problem == VoiceProblem.permission
            ? (_chatUrdu
                ? 'مائیکروفون کی اجازت نہیں۔ سیٹنگز ← ایپس ← بجلی حساب ← اجازتیں میں مائیکروفون آن کریں۔'
                : 'Microphone permission is off. Turn it on in Settings → Apps → Bijli Hisaab → Permissions.')
            : (_chatUrdu ? 'اس فون پر آواز سے لکھنا دستیاب نہیں۔' : 'Voice typing isn\'t available on this phone.'),
      );
      return;
    }
    if (words != null) await _send(words);
  }

  /// Cancel while listening: stop and throw away what was heard.
  Future<void> _cancelVoice() async {
    HapticFeedback.selectionClick();
    await VoiceNumber.cancel();
    if (mounted) setState(() => _input.clear());
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
    _brain.reset();
    context.read<AppState>().clearChat();
    _clearView();
  }

  void _clearView() => setState(_messages.clear);

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
    final chatUrdu = _chatUrdu;
    final state = context.read<AppState>();

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
                    'Answers from your bills & readings'.tr,
                    style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            onPressed: _thinking || _messages.isEmpty ? null : _clear,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // The common questions, always one tap away.
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.amberDeep),
                      label: Text(s, style: _textStyle(theme, s, size: 13)),
                      onPressed: _thinking ? null : () => _send(s),
                      visualDensity: VisualDensity.compact,
                      shape: StadiumBorder(side: BorderSide(color: p.border)),
                      backgroundColor: p.surface,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty && !_thinking
                ? _EmptyState(
                    urdu: chatUrdu,
                    bill: state.bills.firstOrNull,
                    onAsk: _send,
                    suggestions: _suggestions,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i < _messages.length) {
                        final m = _messages[i];
                        final prev = i > 0 ? _messages[i - 1] : null;
                        return _Bubble(m, onAction: _runAction, grouped: prev?.fromUser == m.fromUser);
                      }
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
          if (_listening)
            _VoicePanel(
              level: _level,
              started: _listenStart ?? DateTime.now(),
              transcript: _input.text,
              urdu: chatUrdu,
              onCancel: _cancelVoice,
              onDone: VoiceNumber.stop,
            )
          else
          Material(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border.all(
                            color: _listening ? AppColors.amber : p.border,
                            width: _listening ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Scan or send a bill'.tr,
                              onPressed: _thinking ? null : _attach,
                              icon: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.send,
                                onSubmitted: _send,
                                onChanged: (_) => setState(() {}),
                                style: _textStyle(theme, _input.text.isEmpty && chatUrdu ? 'ا' : _input.text),
                                textDirection: _isUrdu(_input.text) || (_input.text.isEmpty && chatUrdu)
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                decoration: InputDecoration(
                                  hintText: _listening
                                      ? (chatUrdu ? 'سن رہا ہوں… بولیں' : 'Listening… speak now')
                                      : (chatUrdu ? 'اپنے بل کے بارے میں پوچھیں…' : 'Ask about your bill…'),
                                  hintStyle: _textStyle(theme, chatUrdu ? 'ا' : 'a')?.copyWith(color: p.muted),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 14, 12, 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

final _urduScript = RegExp(r'[؀-ۿ]');

/// Mostly Urdu script: shown right to left in Nastaliq.
bool _isUrdu(String text) {
  final letters = text.replaceAll(RegExp(r'[\s\d\p{P}\p{S}]', unicode: true), '');
  if (letters.isEmpty) return false;
  return _urduScript.allMatches(letters).length * 2 >= letters.length;
}

/// Body text for [text]: Nastaliq with room for its tall letters when it's Urdu.
TextStyle? _textStyle(ThemeData theme, String text, {double size = 15}) {
  final base = theme.textTheme.bodyMedium?.copyWith(fontSize: size, height: 1.45);
  if (!_isUrdu(text)) return base;
  return base?.copyWith(fontFamily: AppTheme.urduFontFamily, fontSize: size - 1, height: 2.0);
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.onAction, this.grouped = false});

  final ChatMessage m;
  final Future<void> Function(ReplyAction) onAction;

  /// Same sender as the message above: less space, no avatar.
  final bool grouped;

  void _copy(BuildContext context) {
    if (m.text.isEmpty) return;
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: m.text));
    showSnack(context, 'Copied'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final mine = m.fromUser;
    final urdu = _isUrdu(m.text);
    final ink = mine ? (p.isDark ? AppColors.navy : Colors.white) : p.ink;
    final bg = mine ? (p.isDark ? AppColors.amber : AppColors.navy) : p.surface;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);

    final body = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        border: mine ? null : Border.all(color: p.border),
        borderRadius: BorderRadiusDirectional.only(
          topStart: !mine && grouped ? tail : r,
          topEnd: mine && grouped ? tail : r,
          bottomStart: mine ? r : tail,
          bottomEnd: mine ? tail : r,
        ),
        boxShadow: mine
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.18 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
                    alignment: Alignment.center,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    child: const Icon(Icons.receipt_long_rounded),
                  ),
                ),
              ),
            ),
          if (m.text.isNotEmpty)
            Text(
              m.text,
              textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
              textAlign: urdu ? TextAlign.right : TextAlign.left,
              style: _textStyle(theme, m.text)?.copyWith(color: ink),
            ),
        ],
      ),
    );

    final meta = Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine && m.source != ReplySource.app) ...[
            _SourceTag(m.source),
            const SizedBox(width: 6),
          ],
          Text(
            Fmt.clock(m.time.hour, m.time.minute),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5, color: p.muted),
          ),
        ],
      ),
    );

    final column = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.8 : 0.78)),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onLongPress: () => _copy(context),
            child: Semantics(
              hint: 'Long-press to copy'.tr,
              child: IntrinsicWidth(child: body),
            ),
          ),
          if (m.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in m.actions)
                    ActionChip(
                      label: Text(a.label, style: _textStyle(theme, a.label, size: 13)),
                      avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                      onPressed: () => onAction(a),
                      visualDensity: VisualDensity.compact,
                      shape: StadiumBorder(side: BorderSide(color: AppColors.amber.withValues(alpha: 0.6))),
                      backgroundColor: AppColors.amber.withValues(alpha: p.isDark ? 0.12 : 0.10),
                    ),
                ],
              ),
            ),
          meta,
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: grouped ? 2 : 10),
      child: mine
          ? Align(alignment: AlignmentDirectional.centerEnd, child: column)
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    child: grouped ? null : const AssistantAvatar(size: 28, spark: false),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: column),
                ],
              ),
            ),
    );
  }
}

/// "From your data" / "AI answer" under a reply.
class _SourceTag extends StatelessWidget {
  const _SourceTag(this.source);

  final ReplySource source;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final ai = source == ReplySource.ai;
    final color = ai ? AppColors.amberDeep : p.safe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ai ? Icons.auto_awesome_rounded : Icons.verified_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            ai ? 'AI answer'.tr : 'Answered from your data'.tr,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// No messages yet: what the assistant does, and questions to start with.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.urdu, required this.bill, required this.onAsk, required this.suggestions});

  final bool urdu;
  final Bill? bill;
  final void Function(String) onAsk;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final b = bill;
    final title = urdu ? 'السلام علیکم! میں آپ کا بجلی حساب اسسٹنٹ ہوں' : 'Assalam o alaikum! I\'m your Bijli Hisaab assistant';
    final last = b == null
        ? ''
        : urdu
            ? ' آپ کا ${Fmt.month(b.monthDate)} کا بل ${b.amount > 0 ? Fmt.rs(b.amount) : '${b.units} یونٹ'} تھا۔'
            : ' Your ${Fmt.month(b.monthDate)} bill was ${b.amount > 0 ? Fmt.rs(b.amount) : '${b.units} units'}.';
    final sub = urdu
        ? 'بل کا اندازہ، باقی یونٹ، سلیب، ریٹ اور آلات — آپ کے اپنے ڈیٹا سے فوری جواب۔$last'
        : 'Bill estimate, units left, slab, rates and appliances — answered instantly from your own data.$last';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const Center(child: AssistantAvatar(size: 72)),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
          style: _textStyle(theme, title, size: 18)?.copyWith(fontWeight: FontWeight.w800, color: p.ink),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          textAlign: TextAlign.center,
          textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
          style: _textStyle(theme, sub, size: 14)?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 24),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onAsk(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.amberDeep),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s,
                          textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
                          style: _textStyle(theme, s, size: 14)?.copyWith(fontWeight: FontWeight.w600, color: p.ink),
                        ),
                      ),
                      Icon(urdu ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          urdu
              ? 'آپ کا نام، پتہ یا ریفرنس نمبر کبھی نہیں بھیجا جاتا۔'
              : 'Your name, address and reference number are never sent.',
          textAlign: TextAlign.center,
          style: _textStyle(theme, urdu ? 'ا' : 'a', size: 12)?.copyWith(color: p.muted),
        ),
      ],
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AssistantAvatar(size: 28, spark: false),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(20),
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
                            Transform.translate(
                              offset: Offset(0, -3 * _bounce(_c.value, i)),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.amberDeep.withValues(alpha: 0.45 + 0.55 * _bounce(_c.value, i)),
                                ),
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
                            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
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
            ),
          ],
        ),
      ),
    );
  }

  /// 0→1→0 for dot [i], one after another.
  static double _bounce(double t, int i) {
    final x = (t * 3 - i) % 3;
    return x < 1 ? (x < 0.5 ? x * 2 : (1 - x) * 2) : 0;
  }
}

/// While listening: a live waveform from the microphone level, the words
/// heard so far, a timer, and cancel / done.
class _VoicePanel extends StatefulWidget {
  const _VoicePanel({
    required this.level,
    required this.started,
    required this.transcript,
    required this.urdu,
    required this.onCancel,
    required this.onDone,
  });

  final ValueListenable<double> level;
  final DateTime started;
  final String transcript;
  final bool urdu;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<_VoicePanel> with SingleTickerProviderStateMixin {
  static const _bars = 28;
  late final Ticker _ticker;
  final _heights = List<double>.filled(_bars, 0.08);
  double _smooth = 0;
  Duration _t = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration t) {
    final dt = ((t - _t).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _t = t;
    // Rise fast, fall slowly, like a VU meter.
    final target = widget.level.value;
    _smooth += (target - _smooth) * (target > _smooth ? 18 : 5) * dt;
    final s = t.inMicroseconds / 1e6;
    for (var i = 0; i < _bars; i++) {
      // Taller in the middle, each bar moving at its own pace.
      final centre = 1 - ((i - (_bars - 1) / 2).abs() / (_bars / 2)) * 0.55;
      final wobble = 0.55 + 0.45 * math.sin(s * (7 + (i % 5) * 1.3) + i * 0.9);
      final idle = 0.08 + 0.05 * (0.5 + 0.5 * math.sin(s * 2.2 + i * 0.45));
      final want = math.max(idle, _smooth * centre * wobble);
      _heights[i] += (want - _heights[i]) * math.min(1, 22 * dt);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final secs = DateTime.now().difference(widget.started).inSeconds;
    final timer = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final heard = widget.transcript.trim();
    final pulse = 0.5 + 0.5 * math.sin(_t.inMicroseconds / 1e6 * 4);

    return Material(
      color: p.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.5 + 0.5 * pulse),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.urdu ? 'سن رہا ہوں…' : 'Listening…',
                    style: _textStyle(theme, widget.urdu ? 'ا' : 'a', size: 14)
                        ?.copyWith(fontWeight: FontWeight.w700, color: p.ink),
                  ),
                  const Spacer(),
                  Text(
                    timer,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: p.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: CustomPaint(painter: _WavePainter(_heights, AppColors.amber, AppColors.amberDeep)),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: Text(
                  heard.isEmpty ? (widget.urdu ? 'بولیں، میں لکھ رہا ہوں' : 'Speak — I\'m writing it down') : heard,
                  textAlign: TextAlign.center,
                  textDirection: _isUrdu(heard) || (heard.isEmpty && widget.urdu) ? TextDirection.rtl : TextDirection.ltr,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(theme, heard.isEmpty ? (widget.urdu ? 'ا' : 'a') : heard, size: 15)
                      ?.copyWith(color: heard.isEmpty ? p.muted : p.ink),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    icon: Icons.close_rounded,
                    label: widget.urdu ? 'منسوخ' : 'Cancel',
                    color: p.muted.withValues(alpha: 0.16),
                    iconColor: p.ink,
                    onTap: widget.onCancel,
                  ),
                  // Pulses with the voice.
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: 0.45),
                          blurRadius: 10 + 26 * _smooth,
                          spreadRadius: 2 + 10 * _smooth,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.amber,
                      child: Icon(Icons.mic_rounded, color: AppColors.navy, size: 30),
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.check_rounded,
                    label: widget.urdu ? 'بھیجیں' : 'Send',
                    color: AppColors.navy,
                    iconColor: Colors.white,
                    onTap: widget.onDone,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: color,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(width: 48, height: 48, child: Icon(icon, color: iconColor)),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: _textStyle(Theme.of(context), label, size: 12)),
          ],
        ),
      );
}

/// Rounded bars, mirrored around the middle line.
class _WavePainter extends CustomPainter {
  _WavePainter(this.heights, this.light, this.deep);

  final List<double> heights;
  final Color light;
  final Color deep;

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final gap = size.width / n;
    final w = math.min(6.0, gap * 0.55);
    final mid = size.height / 2;
    for (var i = 0; i < n; i++) {
      final h = math.max(w, heights[i].clamp(0.0, 1.0) * size.height);
      final x = gap * i + gap / 2;
      final paint = Paint()..color = Color.lerp(light, deep, heights[i].clamp(0.0, 1.0))!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, mid), width: w, height: h), Radius.circular(w / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}
