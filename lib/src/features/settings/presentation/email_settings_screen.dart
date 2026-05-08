import 'package:akhiyan_admin/src/features/settings/presentation/settings_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SMTP credentials + outbound mail addresses.
class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

class _EmailSettingsScreenState
    extends SettingsFormState<EmailSettingsScreen> {
  @override
  String get screenTitle => 'Email Settings';

  @override
  Widget buildBody(Map<String, String?> settings) {
    return Column(
      children: [
        SettingsCard(
          icon: Icons.dns_outlined,
          title: 'SMTP server',
          subtitle:
              'Host that sends order confirmations and admin alerts.',
          child: Column(
            children: [
              buildField('smtp_host', 'Host',
                  helper: 'e.g. smtp.gmail.com'),
              buildField('smtp_port', 'Port',
                  keyboardType: TextInputType.number,
                  helper: '587 for STARTTLS, 465 for SSL.'),
              buildField('smtp_user', 'Username',
                  keyboardType: TextInputType.emailAddress),
              buildField('smtp_pass', 'Password', obscure: true),
            ],
          ),
        ),
        SettingsCard(
          icon: Icons.mail_outline,
          title: 'Addresses',
          subtitle:
              'How outbound mail identifies itself, and where alerts go.',
          child: Column(
            children: [
              buildField('smtp_from', 'From address',
                  keyboardType: TextInputType.emailAddress,
                  helper:
                      'Shown in the "From" header on outbound mail.'),
              buildField('smtp_admin_email', 'Admin notification email',
                  keyboardType: TextInputType.emailAddress,
                  helper:
                      'New-order, low-stock, and system alerts go here.'),
            ],
          ),
        ),
      ],
    );
  }
}
