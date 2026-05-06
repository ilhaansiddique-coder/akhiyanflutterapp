import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Body widget shown when an endpoint returns 404 (backend not yet implemented).
Widget comingSoonBody(String featureName) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: const Icon(Icons.hourglass_empty,
                size: 40, color: AppColors.primaryFixed),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '$featureName coming soon',
            style: AppTypography.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This feature is being prepared by the backend team.',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Placeholder for tab screens that haven't been ported from the prototype yet.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Icon(icon, size: 40, color: AppColors.primaryFixed),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This screen is being ported from the Stitch prototype.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
