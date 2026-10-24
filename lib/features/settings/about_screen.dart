import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../core/l10n/l10n.dart';
import '../../state/app_state.dart';
import 'export_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    Widget para(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('About & privacy'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Center(child: ArtTile(Art.brandBolt, onNavy: true, size: 88)),
          const SizedBox(height: 12),
          Center(child: Text(AppConstants.appName, style: theme.textTheme.titleLarge)),
          Center(child: Text('Version 1.0.0'.tr, style: theme.textTheme.bodySmall)),
          const SizedBox(height: 20),
          AppCard(
            elevated: false,
            color: AppColors.amber.withValues(alpha: 0.12),
            borderColor: AppColors.amber.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, color: AppColors.amberDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not an official app'.tr, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(AppConstants.unofficialNotice.tr, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Bills are read from the public PITC bill website, and rates from NEPRA notifications. Always pay through your bank, app or the official bill.'
                            .tr,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('MADE BY'.tr, style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.navy,
                      backgroundImage: AssetImage('assets/images/creator_saad.jpg'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppConstants.creatorName, style: theme.textTheme.titleMedium),
                          Text('Developer & designer'.tr, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text(AppConstants.creatorEmail),
                  subtitle: Text('Feedback, ideas or problems — write to me'.tr),
                  onTap: () => launchUrl(
                    Uri(scheme: 'mailto', path: AppConstants.creatorEmail, query: 'subject=Bijli%20Hisaab%20feedback'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.public_rounded),
                  title: Text('Portfolio'.tr),
                  subtitle: Text(AppConstants.creatorSite.replaceFirst('https://', '').replaceAll(RegExp(r'/$'), '')),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => launchUrl(Uri.parse(AppConstants.creatorSite), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                para(
                  'Estimates only'.tr,
                  'Bill estimates use NEPRA slab rates, fixed charges, FC surcharge, the monthly FCA, the quarterly adjustment and GST. Your DISCO bill is final — arrears, income tax for non-filers and other items can change the amount.'
                      .tr,
                ),
                para(
                  'Your data'.tr,
                  'Everything is stored only on this phone in a local database. There is no account and nothing about you is uploaded. Bill photos are processed on the device with Google ML Kit and are not stored by the app. The app downloads the latest electricity rates, and when you use "Bill online" it sends your reference number to the official bill site of your company (bill.pitc.com.pk) to get your bill. Only the bill figures are saved — never your name or address.'
                      .tr,
                ),
                para(
                  'The assistant'.tr,
                  'Simple requests are answered on your phone. Questions it cannot answer itself, and bill photos (only the figures read on the phone), are sent with your bill figures to a free AI service (Pollinations) to get a reply. Your name, address and reference number are never sent.'
                      .tr,
                ),
                para(
                  'Data export'.tr,
                  'If you allow it, you can export anonymous CSV files (city, DISCO, units, bills, app events) and share them yourself. They contain a random ID, never your name, phone number, bill reference number or address.'
                      .tr,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Allow anonymous data export'.tr),
                  value: state.analyticsConsent,
                  onChanged: state.setAnalyticsConsent,
                ),
                if (state.analyticsConsent)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExportScreen())),
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text('Export data'.tr),
                    ),
                  ),
                const SizedBox(height: 12),
                para(
                  'Credits',
                  '3D illustrations: Microsoft Fluent Emoji (MIT licence). Fonts: Plus Jakarta Sans '
                      'and Noto Nastaliq Urdu (SIL Open Font Licence). Made in Pakistan by Saad Ikram.',
                ),
                para(
                  'Delete everything'.tr,
                  'Tools → Reset app removes all data from this phone. Uninstalling the app also removes it.'.tr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
