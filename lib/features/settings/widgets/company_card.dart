import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/companies.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/company_badge.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../core/l10n/l10n.dart';

/// The active meter's electricity company with quick links.
class CompanyCard extends StatelessWidget {
  const CompanyCard({super.key, required this.company, this.referenceNo = ''});

  final PowerCompany company;

  /// The meter's reference number, shown with a copy button when known.
  final String referenceNo;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showSnack(context, 'Could not open {0}'.trf({'0': uri.toString()}));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = company;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CompanyBadge(c, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName, style: theme.textTheme.titleMedium),
                    Text('${c.group} · ${c.region}',
                        style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          if (!c.usesNepraTariff) ...[
            const SizedBox(height: 10),
            Text(
              'This area has its own tariff set by the regional government. Enter your rates in Electricity rates → Edit for accurate estimates.'.tr,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          if (c.billUrl != null || c.helpline != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.billUrl != null)
                  _Action(
                    icon: Icons.receipt_long_rounded,
                    label: 'View bill online'.tr,
                    onTap: () => _open(context, Uri.parse(c.billUrl!)),
                  ),
                if (c.helpline != null)
                  _Action(
                    icon: Icons.call_rounded,
                    label: 'Call {0}'.trf({'0': c.helpline}),
                    onTap: () => _open(context, Uri(scheme: 'tel', path: c.helpline)),
                  ),
                if (c.website != null && c.website != c.billUrl)
                  _Action(
                    icon: Icons.public_rounded,
                    label: 'Website'.tr,
                    onTap: () => _open(context, Uri.parse(c.website!)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (referenceNo.isEmpty)
              Text('You\'ll need your {0} from the bill.'.trf({'0': c.accountLabel.toLowerCase()}),
                  style: theme.textTheme.bodySmall)
            else
              Material(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: referenceNo.replaceAll(' ', '')));
                    if (context.mounted) showSnack(context, '{0} copied'.trf({'0': c.accountLabel}));
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.accountLabel.toUpperCase(), style: theme.textTheme.labelSmall),
                              Text(referenceNo,
                                  style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        Icon(Icons.copy_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
