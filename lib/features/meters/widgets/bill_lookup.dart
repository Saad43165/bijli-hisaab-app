import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/companies.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/online_bill_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/company_badge.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../state/app_state.dart';
import '../../bills/bill_site_fallback.dart';
import '../../settings/help_screen.dart';

/// Reference-number box + "Find my bill". Looks the number up at every
/// company and reports the bill it finds.
class ReferenceLookup extends StatefulWidget {
  const ReferenceLookup({super.key, required this.onFound});

  final void Function(PowerCompany company, OnlineBill bill) onFound;

  @override
  State<ReferenceLookup> createState() => _ReferenceLookupState();
}

class _ReferenceLookupState extends State<ReferenceLookup> {
  final _ref = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _unreachable = false;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    if (!OnlineBillService.validReference(_ref.text)) {
      setState(() => _error = 'Enter all 14 digits of the reference number'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _unreachable = false;
    });
    try {
      final (company, bill) = await context.read<AppState>().findOnlineBill(_ref.text);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onFound(company, bill);
    } on OnlineBillException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.tr;
          _unreachable = e.siteUnreachable;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ref,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(14),
            ReferenceFormatter(),
          ],
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '06 14562 1211000',
            hintStyle: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              letterSpacing: 1.5,
            ),
            errorText: _error,
            errorMaxLines: 3,
            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _find(),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => HelpScreen.showReferenceHelp(context),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: Text('Where is it on my bill?'.tr),
          ),
        ),
        if (_unreachable && !_busy) ...[
          OutlinedButton.icon(
            onPressed: () => BillSiteFallback.open(context, reference: _ref.text),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text('Open in browser'.tr),
          ),
          const SizedBox(height: 8),
        ],
        LoadingButton(
          loading: _busy,
          onPressed: _find,
          label: _busy ? 'Looking for your bill…'.tr : 'Find my bill'.tr,
          icon: Icons.search_rounded,
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          Text(
            'Checking all electricity companies — this takes a few seconds.'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// "06145621211000" → "06 14562 1211000" as you type.
class ReferenceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 7) b.write(' ');
      b.write(d[i]);
    }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// The bill that was found: company, amount, due date, units, history.
class FoundBillCard extends StatelessWidget {
  const FoundBillCard({super.key, required this.company, required this.bill});

  final PowerCompany company;
  final OnlineBill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = bill;
    final due = b.dueDate;
    final daysLeft =
        due == null ? null : DateUtils.dateOnly(due).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final months = [...b.history.map((m) => (m.month, m.units)), (b.month, b.units)];
    final avg = months.fold<int>(0, (a, m) => a + m.$2) / months.length;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CompanyBadge(company, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.shortCode, style: theme.textTheme.titleMedium),
                    Text('{0} bill'.trf({'0': Fmt.month(b.month)}), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (b.protectedCategory != null)
                _Pill(b.protectedCategory! ? 'Protected'.tr : 'Unprotected'.tr,
                    b.protectedCategory! ? AppPalette.of(context).safe : AppColors.amberDeep),
            ],
          ),
          const SizedBox(height: 18),
          Text('TO PAY'.tr, style: theme.textTheme.labelSmall),
          Text(Fmt.rs(b.amount), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          if (due != null && daysLeft != null)
            Text(
              daysLeft >= 0
                  ? 'Due {0} · {1} days left'.trf({'0': Fmt.day(due), '1': daysLeft})
                  : 'Was due {0}'.trf({'0': Fmt.day(due)}),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: daysLeft < 0 ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat('UNITS'.tr, '${b.units}'),
              _Stat('12-MONTH AVERAGE'.tr, Fmt.whole(avg)),
              _Stat('MONTHS FOUND'.tr, '${months.length}'),
            ],
          ),
          if (months.length > 2) ...[
            const SizedBox(height: 16),
            _MiniBars(months: months),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      );
}

/// Units per month as small bars; the latest bill highlighted.
class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.months});

  final List<(DateTime, int)> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = months.map((m) => m.$2).fold<int>(1, math.max);
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, m) in months.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 50 * m.$2 / top + 2,
                      decoration: BoxDecoration(
                        color: i == months.length - 1
                            ? AppColors.amber
                            : theme.colorScheme.onSurface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.monthShort(m.$1).characters.take(1).toString(),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
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
