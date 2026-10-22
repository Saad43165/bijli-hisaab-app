import 'package:flutter/material.dart';

import '../../../core/constants/companies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/company_badge.dart';
import '../../../core/l10n/l10n.dart';

/// Form field that opens a searchable list of electricity companies.
class CompanyPickerField extends StatelessWidget {
  const CompanyPickerField({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<PowerCompany> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<PowerCompany>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CompanySheet(selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = PowerCompanies.of(value);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Electricity company'.tr,
          contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 14),
        ),
        child: Row(
          children: [
            CompanyBadge(c, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.code == c.fullName ? c.code : '${c.code} · ${c.fullName}',
                      style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  Text(c.region, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CompanySheet extends StatefulWidget {
  const _CompanySheet({required this.selected});

  final String selected;

  @override
  State<_CompanySheet> createState() => _CompanySheetState();
}

class _CompanySheetState extends State<_CompanySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _q.toLowerCase();
    final list = PowerCompanies.all
        .where((c) => q.isEmpty || '${c.code} ${c.fullName} ${c.region}'.toLowerCase().contains(q))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Who sends your bill?'.tr, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('The company name is printed at the top of your bill.'.tr,
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search city or company'.tr,
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final c = list[i];
                final selected = c.code == widget.selected;
                return ListTile(
                  onTap: () => Navigator.pop(context, c),
                  leading: CompanyBadge(c, size: 44),
                  title: Text(c.code == c.fullName ? c.code : '${c.code} — ${c.fullName}',
                      style: theme.textTheme.titleSmall),
                  subtitle: Text(
                    c.usesNepraTariff ? c.region : '{0} · own tariff'.trf({'0': c.region}),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.amberDeep)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
