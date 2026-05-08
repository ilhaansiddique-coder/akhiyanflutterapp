import 'package:akhiyan_admin/src/features/settings/presentation/settings_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Courier credentials — Steadfast and Pathao. Sensitive fields come back
/// masked from the server and are preserved on save unless explicitly
/// overwritten (see [SettingsFormState.buildField]).
class CourierSettingsScreen extends ConsumerStatefulWidget {
  const CourierSettingsScreen({super.key});

  @override
  ConsumerState<CourierSettingsScreen> createState() =>
      _CourierSettingsScreenState();
}

class _CourierSettingsScreenState
    extends SettingsFormState<CourierSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Pathao environment defaults to "production" if the row is empty.
    registerSelect('pathao_environment', 'production');
  }

  @override
  String get screenTitle => 'Courier Settings';

  @override
  Widget buildBody(Map<String, String?> settings) {
    return Column(
      children: [
        SettingsCard(
          icon: Icons.local_shipping_outlined,
          title: 'Steadfast',
          subtitle: 'API credentials for booking Steadfast deliveries.',
          child: Column(
            children: [
              buildField('steadfast_api_key', 'API key', obscure: true),
              buildField('steadfast_secret_key', 'Secret key', obscure: true),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.local_shipping_outlined,
          title: 'Pathao',
          subtitle:
              'OAuth credentials. Area / store pickers stay on web — they '
              'depend on a Pathao geo lookup that needs more screen space.',
          child: Column(
            children: [
              buildSelect(
                'pathao_environment',
                'Environment',
                defaultValue: 'production',
                options: const [
                  DropdownMenuItem(
                      value: 'production', child: Text('Production')),
                  DropdownMenuItem(
                      value: 'sandbox', child: Text('Sandbox')),
                ],
              ),
              buildField('pathao_client_id', 'Client ID'),
              buildField('pathao_client_secret', 'Client secret',
                  obscure: true),
              buildField('pathao_username', 'Merchant username',
                  keyboardType: TextInputType.emailAddress),
              buildField('pathao_password', 'Password', obscure: true),
              buildField(
                'pathao_store_id',
                'Store ID',
                helper:
                    'Pick the store on web admin → Settings → Courier; '
                    'the store id auto-fills here.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
