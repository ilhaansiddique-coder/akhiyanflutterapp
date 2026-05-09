import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/features/settings/presentation/settings_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Language settings — picks default language for the storefront and the
/// admin dashboard separately, with the radio-card UI from the web admin.
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends SettingsFormState<LanguageSettingsScreen> {
  @override
  void initState() {
    super.initState();
    registerSelect('site_language', 'bn');
    registerSelect('dashboard_language', 'en');
  }

  @override
  String get screenTitle => 'Language Settings';

  static const _languages = <_LanguageOption>[
    _LanguageOption(
      code: 'bn',
      flag: 'BD',
      title: 'বাংলা (Bengali)',
      siteSubtitle: 'Shop, products, checkout in Bengali',
      dashSubtitle: 'Dashboard, orders, settings in Bengali',
    ),
    _LanguageOption(
      code: 'en',
      flag: 'GB',
      title: 'English',
      siteSubtitle: 'Shop, products, checkout in English',
      dashSubtitle: 'Dashboard, orders, settings in English',
    ),
  ];

  @override
  Widget buildBody(Map<String, String?> settings) {
    final site = selectValue('site_language') ?? 'bn';
    final dash = selectValue('dashboard_language') ?? 'en';
    return Column(
      children: [
        SettingsCard(
          icon: Icons.public_outlined,
          title: 'Website Language (Frontend)',
          subtitle: 'The language visitors see on your store pages',
          child: Column(
            children: [
              for (final l in _languages)
                _LanguageRadioCard(
                  option: l,
                  selected: site == l.code,
                  subtitle: l.siteSubtitle,
                  onTap: () => setSelect('site_language', l.code),
                ),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard Language (Admin Panel)',
          subtitle: 'The language you see in the admin dashboard',
          child: Column(
            children: [
              for (final l in _languages)
                _LanguageRadioCard(
                  option: l,
                  selected: dash == l.code,
                  subtitle: l.dashSubtitle,
                  onTap: () => setSelect('dashboard_language', l.code),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.flag,
    required this.title,
    required this.siteSubtitle,
    required this.dashSubtitle,
  });

  final String code;
  final String flag;
  final String title;
  final String siteSubtitle;
  final String dashSubtitle;
}

/// Radio-style language card matching the web admin's mobile design — a
/// big tappable card with a flag chip, language name, subtitle, and a
/// custom radio dot. Selected state gets a thick brand-coloured border
/// and a subtle tint.
class _LanguageRadioCard extends StatelessWidget {
  const _LanguageRadioCard({
    required this.option,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  final _LanguageOption option;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md - 2),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.slateBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                _RadioDot(selected: selected),
                const SizedBox(width: AppSpacing.md - 2),
                _FlagChip(label: option.flag),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.title,
                        style: context.h3.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.bodySm.copyWith(
                          color: AppColors.outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outline,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        label,
        style: context.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.onBackground,
        ),
      ),
    );
  }
}
