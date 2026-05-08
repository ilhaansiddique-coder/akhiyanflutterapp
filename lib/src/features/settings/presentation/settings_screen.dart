import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Site-wide settings editor.
///
/// One screen, multiple section anchors, ALL editable. Backed by the
/// unified `/api/v1/m/admin/settings` endpoint — every field reads from
/// and writes to the `siteSetting` table the web admin uses, so a save
/// here propagates to the web admin and vice versa over SSE within
/// seconds.
///
/// Secret fields (SMTP password, Pathao secrets, Steadfast keys) come
/// back masked as `••••••••` from the server. The form renders them as
/// "Saved" placeholders the admin can overwrite — leaving them untouched
/// preserves the existing secret on save (the request strips out any
/// value still equal to the mask).
///
/// Shipping Zones lives in its own table with its own list+CRUD shape —
/// not editable here yet (separate screen needed).
enum SettingsSection {
  site,
  checkout,
  courier,
  email,
  language,
  shipping,
}

extension on SettingsSection {
  String get title => switch (this) {
        SettingsSection.site => 'Site Settings',
        SettingsSection.checkout => 'Checkout Settings',
        SettingsSection.courier => 'Courier Settings',
        SettingsSection.email => 'Email Settings',
        SettingsSection.language => 'Language Settings',
        SettingsSection.shipping => 'Shipping Zones',
      };
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.section = SettingsSection.site});

  final SettingsSection section;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Per-key TextEditingControllers, lazily created. Switch values stored
  // separately as bools.
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, bool> _bools = {};
  final Map<String, String> _selects = {};
  final Map<SettingsSection, GlobalKey> _anchors = {
    for (final s in SettingsSection.values) s: GlobalKey(),
  };
  final _scroll = ScrollController();
  bool _hydrated = false;
  bool _saving = false;

  /// Tracks which keys the user has actually touched. We only PUT changed
  /// keys — saves a round-trip on every "save" tap and keeps the request
  /// payload tiny.
  final Set<String> _dirty = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToSection() {
    final ctx = _anchors[widget.section]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  TextEditingController _ctrl(String key, String initial) {
    return _ctrls.putIfAbsent(key, () {
      final c = TextEditingController(text: initial);
      // Mark dirty on any change so save knows what to send.
      c.addListener(() {
        if (c.text != initial) _dirty.add(key);
      });
      return c;
    });
  }

  void _hydrate(Map<String, String?> settings) {
    if (_hydrated) return;
    _hydrated = true;
    // Text fields — string keys.
    const stringKeys = [
      // Site
      'site_name', 'site_tagline', 'site_description',
      'contact_email', 'contact_phone', 'contact_address',
      'currency', 'site_logo', 'favicon',
      // Checkout — copy
      'checkout_title', 'checkout_subtitle', 'checkout_btn_text',
      'checkout_success_msg', 'checkout_guarantee_text',
      'checkout_bkash_number', 'checkout_bkash_instruction',
      'checkout_nagad_number', 'checkout_nagad_instruction',
      // Courier
      'steadfast_api_key', 'steadfast_secret_key',
      'pathao_client_id', 'pathao_client_secret',
      'pathao_username', 'pathao_password', 'pathao_store_id',
      // Email
      'smtp_host', 'smtp_port', 'smtp_user', 'smtp_pass',
      'smtp_from', 'smtp_admin_email',
    ];
    for (final k in stringKeys) {
      _ctrl(k, settings[k] ?? '');
    }

    // Boolean toggles — stored as 'true'/'false' strings server-side.
    const boolKeys = [
      'checkout_show_email', 'checkout_show_zip', 'checkout_show_notes',
      'checkout_show_coupon',
      'checkout_payment_cod', 'checkout_payment_bkash',
      'checkout_payment_nagad',
    ];
    for (final k in boolKeys) {
      _bools[k] = (settings[k] ?? 'false').toLowerCase() == 'true';
    }

    // Selects.
    _selects['pathao_environment'] =
        settings['pathao_environment'] ?? 'production';
    _selects['site_language'] = settings['site_language'] ?? 'bn';
    _selects['dashboard_language'] = settings['dashboard_language'] ?? 'en';
  }

  void _setBool(String key, bool value) {
    setState(() {
      _bools[key] = value;
      _dirty.add(key);
    });
  }

  void _setSelect(String key, String value) {
    setState(() {
      _selects[key] = value;
      _dirty.add(key);
    });
  }

  Future<void> _save() async {
    if (_dirty.isEmpty) {
      _toast('Nothing to save');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, String?>{};
      for (final key in _dirty) {
        if (_bools.containsKey(key)) {
          payload[key] = _bools[key]! ? 'true' : 'false';
        } else if (_selects.containsKey(key)) {
          payload[key] = _selects[key];
        } else if (_ctrls.containsKey(key)) {
          // Leave masked secret alone — the API helper strips it too,
          // but checking here keeps the dirty set honest.
          final v = _ctrls[key]!.text;
          if (v != api.kSecretMask) payload[key] = v;
        }
      }
      if (payload.isEmpty) {
        _toast('Nothing to save');
        return;
      }
      await ref.read(akhiyanApiProvider).adminSettings.save(payload);
      _dirty.clear();
      // Refetch so the SettingsScreen reflects any server-side
      // normalisation (e.g. site_url trimmed of trailing slash).
      ref.invalidate(adminSettingsProvider);
      if (!mounted) return;
      _toast('Saved');
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Save failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(adminSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          widget.section.title,
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load settings.\n$e',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        data: (settings) {
          _hydrate(settings);
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(adminSettingsProvider),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                  children: [
                    _SiteSection(
                      anchor: _anchors[SettingsSection.site]!,
                      ctrl: _ctrl,
                      settings: settings,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CheckoutSection(
                      anchor: _anchors[SettingsSection.checkout]!,
                      ctrl: _ctrl,
                      bools: _bools,
                      onBool: _setBool,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CourierSection(
                      anchor: _anchors[SettingsSection.courier]!,
                      ctrl: _ctrl,
                      env: _selects['pathao_environment']!,
                      onEnvChanged: (v) =>
                          _setSelect('pathao_environment', v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _EmailSection(
                      anchor: _anchors[SettingsSection.email]!,
                      ctrl: _ctrl,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _LanguageSection(
                      anchor: _anchors[SettingsSection.language]!,
                      site: _selects['site_language']!,
                      dash: _selects['dashboard_language']!,
                      onSiteChanged: (v) => _setSelect('site_language', v),
                      onDashChanged: (v) =>
                          _setSelect('dashboard_language', v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ShippingSection(
                        anchor: _anchors[SettingsSection.shipping]!),
                  ],
                ),
              ),
              _SaveBar(
                dirty: _dirty.length,
                saving: _saving,
                onSave: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Reusable section card ──────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.anchorKey,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final Key anchorKey;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.h3.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onBackground)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.outline, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.md - 2),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.helper,
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final isMasked = controller.text == api.kSecretMask;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: keyboardType,
        obscureText: obscure && !isMasked,
        decoration: InputDecoration(
          labelText: label,
          helperText: isMasked
              ? 'Stored. Type a new value to overwrite.'
              : helper,
          helperMaxLines: 2,
          isDense: true,
          border: const OutlineInputBorder(),
          // Don't reveal the mask dots as if they were the saved value —
          // gray it out so it reads as a placeholder.
          hintStyle: TextStyle(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
        onTap: isMasked
            ? () {
                // First tap on a masked secret: clear so the admin types
                // the real value, not appends to the mask glyphs.
                controller.clear();
              }
            : null,
      ),
    );
  }
}

// ─── Site Section ───────────────────────────────────────────────────────────

class _SiteSection extends StatelessWidget {
  const _SiteSection({
    required this.anchor,
    required this.ctrl,
    required this.settings,
  });

  final GlobalKey anchor;
  final TextEditingController Function(String, String) ctrl;
  final Map<String, String?> settings;

  @override
  Widget build(BuildContext context) {
    return _Section(
      anchorKey: anchor,
      title: 'Site',
      subtitle: 'Branding, contact details, currency.',
      children: [
        _Field(
          label: 'Site name',
          controller: ctrl('site_name', settings['site_name'] ?? ''),
        ),
        _Field(
          label: 'Tagline',
          controller: ctrl('site_tagline', settings['site_tagline'] ?? ''),
        ),
        _Field(
          label: 'Description',
          controller:
              ctrl('site_description', settings['site_description'] ?? ''),
          maxLines: 3,
        ),
        _Field(
          label: 'Logo URL',
          controller: ctrl('site_logo', settings['site_logo'] ?? ''),
          helper: 'Public URL to the logo image used in the storefront and admin sidebar.',
        ),
        _Field(
          label: 'Favicon URL',
          controller: ctrl('favicon', settings['favicon'] ?? ''),
        ),
        _Field(
          label: 'Contact email',
          controller:
              ctrl('contact_email', settings['contact_email'] ?? ''),
          keyboardType: TextInputType.emailAddress,
        ),
        _Field(
          label: 'Contact phone',
          controller:
              ctrl('contact_phone', settings['contact_phone'] ?? ''),
          keyboardType: TextInputType.phone,
        ),
        _Field(
          label: 'Address',
          controller:
              ctrl('contact_address', settings['contact_address'] ?? ''),
          maxLines: 2,
        ),
        _Field(
          label: 'Currency',
          controller: ctrl('currency', settings['currency'] ?? 'BDT'),
          helper: 'ISO code, e.g. BDT, USD.',
        ),
      ],
    );
  }
}

// ─── Checkout Section ───────────────────────────────────────────────────────

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.anchor,
    required this.ctrl,
    required this.bools,
    required this.onBool,
  });

  final GlobalKey anchor;
  final TextEditingController Function(String, String) ctrl;
  final Map<String, bool> bools;
  final void Function(String, bool) onBool;

  @override
  Widget build(BuildContext context) {
    return _Section(
      anchorKey: anchor,
      title: 'Checkout',
      subtitle: 'Form copy, payment methods, and visible fields.',
      children: [
        _Field(label: 'Form title', controller: ctrl('checkout_title', '')),
        _Field(
            label: 'Form subtitle',
            controller: ctrl('checkout_subtitle', ''),
            maxLines: 2),
        _Field(
            label: 'Checkout button text',
            controller: ctrl('checkout_btn_text', '')),
        _Field(
            label: 'Success message',
            controller: ctrl('checkout_success_msg', ''),
            maxLines: 2),
        _Field(
            label: 'Guarantee text',
            controller: ctrl('checkout_guarantee_text', ''),
            maxLines: 2),
        const SizedBox(height: AppSpacing.sm),
        _SwitchTile(
          label: 'Show email field',
          value: bools['checkout_show_email'] ?? false,
          onChanged: (v) => onBool('checkout_show_email', v),
        ),
        _SwitchTile(
          label: 'Show ZIP / postcode',
          value: bools['checkout_show_zip'] ?? false,
          onChanged: (v) => onBool('checkout_show_zip', v),
        ),
        _SwitchTile(
          label: 'Show order notes',
          value: bools['checkout_show_notes'] ?? true,
          onChanged: (v) => onBool('checkout_show_notes', v),
        ),
        _SwitchTile(
          label: 'Show coupon code field',
          value: bools['checkout_show_coupon'] ?? true,
          onChanged: (v) => onBool('checkout_show_coupon', v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Payment methods',
            style: AppTypography.bodySm.copyWith(
                color: AppColors.outline,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
        _SwitchTile(
          label: 'Cash on delivery',
          value: bools['checkout_payment_cod'] ?? true,
          onChanged: (v) => onBool('checkout_payment_cod', v),
        ),
        _SwitchTile(
          label: 'bKash',
          value: bools['checkout_payment_bkash'] ?? false,
          onChanged: (v) => onBool('checkout_payment_bkash', v),
        ),
        if (bools['checkout_payment_bkash'] ?? false) ...[
          _Field(
              label: 'bKash number',
              controller: ctrl('checkout_bkash_number', '')),
          _Field(
              label: 'bKash instructions',
              controller: ctrl('checkout_bkash_instruction', ''),
              maxLines: 2),
        ],
        _SwitchTile(
          label: 'Nagad',
          value: bools['checkout_payment_nagad'] ?? false,
          onChanged: (v) => onBool('checkout_payment_nagad', v),
        ),
        if (bools['checkout_payment_nagad'] ?? false) ...[
          _Field(
              label: 'Nagad number',
              controller: ctrl('checkout_nagad_number', '')),
          _Field(
              label: 'Nagad instructions',
              controller: ctrl('checkout_nagad_instruction', ''),
              maxLines: 2),
        ],
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(label,
          style: AppTypography.bodyMd.copyWith(
              fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Courier Section ────────────────────────────────────────────────────────

class _CourierSection extends StatelessWidget {
  const _CourierSection({
    required this.anchor,
    required this.ctrl,
    required this.env,
    required this.onEnvChanged,
  });

  final GlobalKey anchor;
  final TextEditingController Function(String, String) ctrl;
  final String env;
  final ValueChanged<String> onEnvChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      anchorKey: anchor,
      title: 'Courier',
      subtitle:
          'Pathao + Steadfast credentials. Pathao area / store pickers '
          'stay on web — they need a geo lookup that needs more screen space.',
      children: [
        Text('Steadfast',
            style: AppTypography.bodySm.copyWith(
                color: AppColors.outline,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
        _Field(
            label: 'API key',
            controller: ctrl('steadfast_api_key', ''),
            obscure: true),
        _Field(
            label: 'Secret key',
            controller: ctrl('steadfast_secret_key', ''),
            obscure: true),
        const SizedBox(height: AppSpacing.sm),
        Text('Pathao',
            style: AppTypography.bodySm.copyWith(
                color: AppColors.outline,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String>(
            initialValue: env,
            decoration: const InputDecoration(
              labelText: 'Environment',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                  value: 'production', child: Text('Production')),
              DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')),
            ],
            onChanged: (v) => onEnvChanged(v ?? env),
          ),
        ),
        _Field(
            label: 'Client ID', controller: ctrl('pathao_client_id', '')),
        _Field(
            label: 'Client secret',
            controller: ctrl('pathao_client_secret', ''),
            obscure: true),
        _Field(
            label: 'Username (merchant email)',
            controller: ctrl('pathao_username', ''),
            keyboardType: TextInputType.emailAddress),
        _Field(
            label: 'Password',
            controller: ctrl('pathao_password', ''),
            obscure: true),
        _Field(
            label: 'Store ID',
            controller: ctrl('pathao_store_id', ''),
            helper:
                'Pick the store on web admin → Settings → Courier; it '
                'auto-fills here.'),
      ],
    );
  }
}

// ─── Email Section ──────────────────────────────────────────────────────────

class _EmailSection extends StatelessWidget {
  const _EmailSection({required this.anchor, required this.ctrl});

  final GlobalKey anchor;
  final TextEditingController Function(String, String) ctrl;

  @override
  Widget build(BuildContext context) {
    return _Section(
      anchorKey: anchor,
      title: 'Email (SMTP)',
      subtitle: 'Outbound mail server for order confirmations and admin alerts.',
      children: [
        _Field(
            label: 'SMTP host',
            controller: ctrl('smtp_host', ''),
            helper: 'e.g. smtp.gmail.com'),
        _Field(
            label: 'Port',
            controller: ctrl('smtp_port', ''),
            keyboardType: TextInputType.number,
            helper: '587 for STARTTLS, 465 for SSL.'),
        _Field(
            label: 'Username',
            controller: ctrl('smtp_user', ''),
            keyboardType: TextInputType.emailAddress),
        _Field(
            label: 'Password',
            controller: ctrl('smtp_pass', ''),
            obscure: true),
        _Field(
            label: 'From address',
            controller: ctrl('smtp_from', ''),
            keyboardType: TextInputType.emailAddress,
            helper: 'Address shown in the "From" header on outbound mail.'),
        _Field(
            label: 'Admin notification email',
            controller: ctrl('smtp_admin_email', ''),
            keyboardType: TextInputType.emailAddress,
            helper:
                'Where new-order, low-stock, and system alerts get sent.'),
      ],
    );
  }
}

// ─── Language Section ───────────────────────────────────────────────────────

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({
    required this.anchor,
    required this.site,
    required this.dash,
    required this.onSiteChanged,
    required this.onDashChanged,
  });

  final GlobalKey anchor;
  final String site;
  final String dash;
  final ValueChanged<String> onSiteChanged;
  final ValueChanged<String> onDashChanged;

  static const _options = [
    DropdownMenuItem(value: 'bn', child: Text('Bangla (বাংলা)')),
    DropdownMenuItem(value: 'en', child: Text('English')),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      anchorKey: anchor,
      title: 'Language',
      subtitle:
          'Pick the default language for the storefront and the admin '
          'dashboard separately.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String>(
            initialValue: site,
            decoration: const InputDecoration(
              labelText: 'Storefront language',
              helperText: 'What visitors see on shop pages',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _options,
            onChanged: (v) => onSiteChanged(v ?? site),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String>(
            initialValue: dash,
            decoration: const InputDecoration(
              labelText: 'Dashboard language',
              helperText: 'What admins see in the dashboard',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _options,
            onChanged: (v) => onDashChanged(v ?? dash),
          ),
        ),
      ],
    );
  }
}

// ─── Shipping Zones (placeholder) ───────────────────────────────────────────

class _ShippingSection extends StatelessWidget {
  const _ShippingSection({required this.anchor});

  final GlobalKey anchor;

  @override
  Widget build(BuildContext context) {
    return _Section(
      anchorKey: anchor,
      title: 'Shipping Zones',
      subtitle:
          'Zone editing has its own list/CRUD shape, separate from the '
          'key-value settings above. Manage zones on web admin under '
          'Settings → Shipping for now — a dedicated mobile screen can '
          'follow once the design is locked.',
      children: const [],
    );
  }
}

// ─── Floating save bar ──────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final int dirty;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.of(context).padding.bottom + AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.slateBorder)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (dirty > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  '$dirty unsaved',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.outline, fontSize: 12),
                ),
              ),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: saving || dirty == 0 ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(dirty == 0
                          ? 'No changes'
                          : 'Save $dirty change${dirty == 1 ? '' : 's'}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
