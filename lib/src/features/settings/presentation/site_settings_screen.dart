import 'package:akhiyan_admin/src/features/settings/presentation/settings_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Site Settings — branding, contact info, currency. Read-write via the
/// shared `/m/admin/settings` endpoint. Live-updates over the `settings`
/// SSE channel.
class SiteSettingsScreen extends ConsumerStatefulWidget {
  const SiteSettingsScreen({super.key});

  @override
  ConsumerState<SiteSettingsScreen> createState() =>
      _SiteSettingsScreenState();
}

class _SiteSettingsScreenState
    extends SettingsFormState<SiteSettingsScreen> {
  @override
  String get screenTitle => 'Site Settings';

  @override
  Widget buildBody(Map<String, String?> settings) {
    return Column(
      children: [
        SettingsCard(
          icon: Icons.storefront_outlined,
          title: 'Branding',
          subtitle: 'Name, tagline, logo, and favicon shown across the storefront and admin.',
          child: Column(
            children: [
              buildField('site_name', 'Site name'),
              buildField('site_tagline', 'Tagline'),
              buildField('site_description', 'Description', maxLines: 3),
              buildField('site_logo', 'Logo URL',
                  helper:
                      'Public URL to the logo image used in the storefront and the mobile sidebar.'),
              buildField('favicon', 'Favicon URL'),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.contact_mail_outlined,
          title: 'Contact details',
          subtitle: 'Where customers and emails reach you.',
          child: Column(
            children: [
              buildField('contact_email', 'Contact email',
                  keyboardType: TextInputType.emailAddress),
              buildField('contact_phone', 'Contact phone',
                  keyboardType: TextInputType.phone),
              buildField('contact_address', 'Address', maxLines: 2),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.attach_money_outlined,
          title: 'Currency',
          subtitle: 'ISO code shown on prices and invoices.',
          child: buildField('currency', 'Currency',
              helper: 'e.g. BDT, USD.'),
        ),
      ],
    );
  }
}
