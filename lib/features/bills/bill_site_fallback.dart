import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/companies.dart';
import '../../core/l10n/l10n.dart';
import '../../services/online_bill_service.dart';
import '../../shared/widgets/dialogs.dart';

/// When the app can't reach the bill site: opens the official bill page in
/// the browser with the reference number copied, ready to paste.
class BillSiteFallback {
  BillSiteFallback._();

  static Future<void> open(BuildContext context, {PowerCompany? company, String? reference}) async {
    final ref = OnlineBillService.digitsOf(reference ?? '');
    if (ref.isNotEmpty) await Clipboard.setData(ClipboardData(text: ref));
    final url = company?.billUrl ?? 'https://bill.pitc.com.pk';
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    showSnack(
      context,
      !ok
          ? 'Could not open the browser.'.tr
          : ref.isEmpty
              ? 'Opening the official bill site…'.tr
              : 'Reference number copied — paste it on the bill site.'.tr,
    );
  }

  /// A snack bar for [e], with "Open in browser" when the site is unreachable.
  static void snack(BuildContext context, OnlineBillException e, {PowerCompany? company, String? reference}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(e.message.tr),
        duration: Duration(seconds: e.siteUnreachable ? 8 : 4),
        action: e.siteUnreachable
            ? SnackBarAction(
                label: 'Open in browser'.tr,
                onPressed: () => open(context, company: company, reference: reference),
              )
            : null,
      ));
  }
}
