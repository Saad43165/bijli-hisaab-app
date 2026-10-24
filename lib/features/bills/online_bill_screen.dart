import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/companies.dart';
import '../../core/l10n/l10n.dart';
import '../../core/utils/formatters.dart';
import '../../services/online_bill_service.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets/dialogs.dart';

/// The company's official bill page inside the app. On PITC pages (all
/// WAPDA DISCOs) the reference number is filled in and searched for you.
class OnlineBillScreen extends StatefulWidget {
  const OnlineBillScreen({super.key, required this.company, this.referenceNo = ''});

  final PowerCompany company;
  final String referenceNo;

  static Future<void> open(BuildContext context, PowerCompany company, String referenceNo) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnlineBillScreen(company: company, referenceNo: referenceNo),
      ));

  @override
  State<OnlineBillScreen> createState() => _OnlineBillScreenState();
}

class _OnlineBillScreenState extends State<OnlineBillScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _filled = false;
  bool _failed = false;
  bool _saved = false;

  String get _ref => widget.referenceNo.replaceAll(RegExp(r'\D'), '');
  bool get _isPitc => widget.company.billUrl?.contains('bill.pitc.com.pk') ?? false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _failed = false),
        onPageFinished: (url) {
          _autoFill();
          if (url.contains('/general')) _saveShownBill();
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _failed = true);
        },
      ))
      ..loadRequest(Uri.parse(widget.company.billUrl!));
  }

  /// Fill the 14-digit reference number and press Search, once.
  Future<void> _autoFill() async {
    if (_filled || !_isPitc || _ref.length != 14) return;
    _filled = true;
    final ref = jsonEncode(_ref);
    await _web.runJavaScript('''
(function () {
  var box = document.getElementById('searchTextBox');
  if (!box) return;
  var byRef = document.getElementById('rbSearchByList_0');
  if (byRef) byRef.checked = true;
  box.value = $ref;
  var btn = document.getElementById('btnSearch');
  if (btn) btn.click();
})();
''');
  }

  /// Reads the bill on screen and saves it (with its history) to this
  /// meter, so the due-date reminder and history stay up to date.
  Future<void> _saveShownBill() async {
    if (_saved) return;
    final state = context.read<AppState>();
    final meterRef = OnlineBillService.digitsOf(state.activeMeter?.referenceNo ?? '');
    try {
      final text = await _web.runJavaScriptReturningResult('document.body.innerText');
      var raw = text is String ? text : '$text';
      if (raw.startsWith('"')) raw = jsonDecode(raw) as String;
      final bill = OnlineBillParser.parse(raw, reference: _ref);
      if (bill == null || !mounted) return;
      // Only the active meter's own bill (or a meter with no number yet).
      if (meterRef.isNotEmpty && meterRef != bill.reference) return;
      _saved = true;
      final fresh = await state.importOnlineBill(bill);
      if (!mounted) return;
      showSnack(
        context,
        (fresh > 0 ? 'Saved {0} months to your history.' : 'Your history is up to date.').trf({'0': fresh}) +
            (bill.dueDate == null
                ? ''
                : ' ${'Reminder set for the due date ({0}).'.trf({'0': Fmt.dayShort(bill.dueDate!)})}'),
      );
    } catch (e) {
      debugPrint('Could not read the bill page: $e');
    }
  }

  Future<void> _copyRef() async {
    await Clipboard.setData(ClipboardData(text: _ref));
    if (mounted) showSnack(context, '{0} copied'.trf({'0': widget.company.accountLabel}));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('{0} bill'.trf({'0': widget.company.shortCode})),
          actions: [
            if (_ref.isNotEmpty)
              IconButton(
                tooltip: 'Copy reference number'.tr,
                icon: const Icon(Icons.copy_rounded),
                onPressed: _copyRef,
              ),
            IconButton(
              tooltip: 'Reload'.tr,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                _filled = false;
                _web.loadRequest(Uri.parse(widget.company.billUrl!));
              },
            ),
            PopupMenuButton<int>(
              onSelected: (_) async {
                final url = await _web.currentUrl() ?? widget.company.billUrl!;
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              itemBuilder: (_) => [PopupMenuItem(value: 0, child: Text('Open in browser'.tr))],
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
                )
              : null,
        ),
        body: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('Couldn\'t open the bill page. Check your internet and try again.'.tr,
                          textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          _filled = false;
                          _web.loadRequest(Uri.parse(widget.company.billUrl!));
                        },
                        child: Text('Try again'.tr),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Text(
                      'Official {0} bill page (PITC website), shown inside Bijli Hisaab — an independent app.'
                          .trf({'0': widget.company.shortCode}),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(child: WebViewWidget(controller: _web)),
                ],
              ),
      ),
    );
  }
}
