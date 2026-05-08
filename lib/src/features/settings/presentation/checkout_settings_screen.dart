import 'package:akhiyan_admin/src/features/settings/presentation/settings_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Checkout settings — copy strings, visible-fields toggles, payment methods.
class CheckoutSettingsScreen extends ConsumerStatefulWidget {
  const CheckoutSettingsScreen({super.key});

  @override
  ConsumerState<CheckoutSettingsScreen> createState() =>
      _CheckoutSettingsScreenState();
}

class _CheckoutSettingsScreenState
    extends SettingsFormState<CheckoutSettingsScreen> {
  @override
  String get screenTitle => 'Checkout Settings';

  @override
  Widget buildBody(Map<String, String?> settings) {
    final bkashOn = (settings['checkout_payment_bkash'] ?? 'false')
            .toLowerCase() ==
        'true';
    final nagadOn = (settings['checkout_payment_nagad'] ?? 'false')
            .toLowerCase() ==
        'true';
    return Column(
      children: [
        SettingsCard(
          icon: Icons.text_fields_outlined,
          title: 'Form copy',
          subtitle: 'Headings and call-to-action text on the checkout page.',
          child: Column(
            children: [
              buildField('checkout_title', 'Form title'),
              buildField('checkout_subtitle', 'Form subtitle', maxLines: 2),
              buildField('checkout_btn_text', 'Checkout button text'),
              buildField('checkout_success_msg', 'Success message',
                  maxLines: 2),
              buildField('checkout_guarantee_text', 'Guarantee text',
                  maxLines: 2),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.tune_outlined,
          title: 'Visible fields',
          subtitle: 'Toggle which optional fields appear on the checkout form.',
          child: Column(
            children: [
              buildSwitch('checkout_show_email', 'Show email field'),
              buildSwitch('checkout_show_zip', 'Show ZIP / postcode'),
              buildSwitch('checkout_show_notes', 'Show order notes',
                  defaultValue: true),
              buildSwitch('checkout_show_coupon', 'Show coupon code',
                  defaultValue: true),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.payments_outlined,
          title: 'Payment methods',
          subtitle: 'Enable the methods customers can use at checkout.',
          child: Column(
            children: [
              buildSwitch('checkout_payment_cod', 'Cash on delivery',
                  defaultValue: true),
              buildSwitch('checkout_payment_bkash', 'bKash'),
              if (bkashOn) ...[
                buildField('checkout_bkash_number', 'bKash number'),
                buildField('checkout_bkash_instruction', 'bKash instructions',
                    maxLines: 2),
              ],
              buildSwitch('checkout_payment_nagad', 'Nagad'),
              if (nagadOn) ...[
                buildField('checkout_nagad_number', 'Nagad number'),
                buildField('checkout_nagad_instruction', 'Nagad instructions',
                    maxLines: 2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
