import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../core/l10n/l10n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Center(
            child: const ArtTile(Art.brandBolt, onNavy: true, size: 88),
          ),
          const SizedBox(height: 12),
          Center(child: Text(AppConstants.appName, style: theme.textTheme.titleLarge)),
          Center(child: Text('Version 1.0.0'.tr, style: theme.textTheme.bodySmall)),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                para(
                  'Estimates only',
                  'Bill estimates use NEPRA slab rates, fixed charges, FC surcharge, the monthly '
                      'FCA, the quarterly adjustment and GST. Your DISCO bill is final — arrears, '
                      'income tax for non-filers and other items can change the amount.',
                ),
                para(
                  'Your data',
                  'Everything is stored only on this phone in a local database. There is no '
                      'account and nothing about you is uploaded. Bill photos are processed on the '
                      'device with Google ML Kit and are not stored by the app. The app only '
                      'downloads the latest electricity rates.',
                ),
                para(
                  'Data export',
                  'If you allow it, you can export anonymous CSV files (city, DISCO, units, bills, '
                      'app events) and share them yourself. They contain a random ID, never your name, '
                      'phone number, bill reference number or address.',
                ),
                para(
                  'Credits',
                  '3D illustrations: Microsoft Fluent Emoji (MIT licence). Fonts: Plus Jakarta Sans '
                      'and Noto Nastaliq Urdu (SIL Open Font Licence). Bijli Hisaab is an independent '
                      'app and is not affiliated with NEPRA, WAPDA, any DISCO or K-Electric.',
                ),
                para(
                  'Delete everything',
                  'Tools → Reset app removes all data from this phone. Uninstalling the app also '
                      'removes it.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
