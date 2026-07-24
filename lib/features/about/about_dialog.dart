import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/open_external.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Shows the Project8X About dialog.
Future<void> showAboutAppDialog(
  BuildContext context, {
  OpenExternal openExternal = openExternalUri,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AboutAppDialog(openExternal: openExternal),
  );
}

class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({
    super.key,
    this.openExternal = openExternalUri,
  });

  final OpenExternal openExternal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      key: const Key('about_dialog'),
      backgroundColor: AppColors.surfaceElevated,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppInfo.name,
            key: const Key('about_app_name'),
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            AppInfo.versionLabel,
            key: const Key('about_version'),
            style: textTheme.bodyMedium?.copyWith(
              fontFamily: AppTheme.monoFont,
              color: AppColors.primaryBright,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A ${AppInfo.companyName} product',
                key: const Key('about_company'),
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppInfo.productLine,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                AppInfo.companyBlurb,
                key: const Key('about_blurb'),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 20),
              Text('Support', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              SelectableText(
                AppInfo.supportEmail,
                key: const Key('about_support_email'),
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.monoFont,
                  color: AppColors.primaryBright,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('about_open_mail'),
                    onPressed: () => openExternal(AppInfo.supportMailto),
                    child: const Text('Email support'),
                  ),
                  OutlinedButton(
                    key: const Key('about_open_website'),
                    onPressed: () => openExternal(AppInfo.websiteUrl),
                    child: const Text('Website'),
                  ),
                  OutlinedButton(
                    key: const Key('about_open_contact'),
                    onPressed: () => openExternal(AppInfo.contactUrl),
                    child: const Text('Contact Us'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('about_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
