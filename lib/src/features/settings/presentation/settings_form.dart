import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared scaffolding every per-section settings screen reuses: hydrate
/// from `adminSettingsProvider`, track per-key dirty state, and ship a
/// floating save bar that PUTs only what changed.
///
/// Usage:
///   ```dart
///   class FooSettingsScreen extends ConsumerStatefulWidget { … }
///
///   class _FooSettingsScreenState extends SettingsFormState<FooSettingsScreen> {
///     @override
///     Widget buildBody(Map<String, String?> settings) {
///       return Column(children: [
///         buildField('site_name', 'Site name'),
///         buildSwitch('checkout_payment_cod', 'Cash on delivery'),
///       ]);
///     }
///   }
///   ```
abstract class SettingsFormState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  /// Title shown in the AppBar. Override.
  String get screenTitle;

  /// Build the section-specific body once `settings` resolves. Use
  /// [buildField], [buildSwitch], [buildSelect] to wire fields.
  Widget buildBody(Map<String, String?> settings);

  // ─── Internal state ──────────────────────────────────────────────────────

  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, bool> _bools = {};
  final Map<String, String> _selects = {};
  final Set<String> _dirty = {};
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Field builders subclasses use ───────────────────────────────────────

  /// Editable text field bound to [key] in the settings map. Marks dirty
  /// on first edit; renders a "Stored. Type to overwrite." helper if the
  /// initial value is the [api.kSecretMask] sentinel.
  Widget buildField(
    String key,
    String label, {
    String? helper,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    final ctrl = _ctrl(key);
    final isMasked = ctrl.text == api.kSecretMask;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: keyboardType,
        obscureText: obscure && !isMasked,
        decoration: InputDecoration(
          labelText: label,
          helperText:
              isMasked ? 'Stored. Type a new value to overwrite.' : helper,
          helperMaxLines: 2,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onTap: isMasked
            ? () {
                // First tap on a masked secret: clear so the admin types
                // the real value rather than appending to the mask glyphs.
                ctrl.clear();
              }
            : null,
      ),
    );
  }

  Widget buildSwitch(String key, String label, {bool defaultValue = false}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: _bools[key] ?? defaultValue,
      onChanged: (v) {
        setState(() {
          _bools[key] = v;
          _dirty.add(key);
        });
      },
      title: Text(label,
          style: AppTypography.bodyMd.copyWith(
              fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget buildSelect(
    String key,
    String label, {
    required List<DropdownMenuItem<String>> options,
    required String defaultValue,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: _selects[key] ?? defaultValue,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: options,
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _selects[key] = v;
            _dirty.add(key);
          });
        },
      ),
    );
  }

  /// Read the current select value (used by screens that render their own
  /// custom UI for a single key, e.g. the Language screen's radio cards).
  String? selectValue(String key) => _selects[key];

  /// Imperatively change a select's value — for screens (like Language)
  /// that pick via tappable cards instead of a Material dropdown.
  void setSelect(String key, String value) {
    setState(() {
      _selects[key] = value;
      _dirty.add(key);
    });
  }

  /// Subclasses call this from `initState` to seed defaults for keys that
  /// aren't text fields (selects + switches). Text fields hydrate lazily
  /// via [_ctrl] on first build.
  void registerSelect(String key, String defaultValue) {
    _selects.putIfAbsent(key, () => defaultValue);
  }

  void registerBool(String key, bool defaultValue) {
    _bools.putIfAbsent(key, () => defaultValue);
  }

  // ─── Plumbing ────────────────────────────────────────────────────────────

  TextEditingController _ctrl(String key) {
    return _ctrls.putIfAbsent(key, () {
      final initial = _initialFor(key) ?? '';
      final c = TextEditingController(text: initial);
      c.addListener(() {
        if (c.text != initial) _dirty.add(key);
      });
      return c;
    });
  }

  Map<String, String?> _settings = const {};
  String? _initialFor(String key) => _settings[key];

  void _hydrate(Map<String, String?> settings) {
    _settings = settings;
    if (_hydrated) return;
    _hydrated = true;

    // Bool keys we know about across all sections — populate from the
    // server. Text keys hydrate lazily on first _ctrl() call. Select keys
    // are seeded by subclasses in initState via registerSelect().
    const knownBoolKeys = [
      'checkout_show_email', 'checkout_show_zip', 'checkout_show_notes',
      'checkout_show_coupon',
      'checkout_payment_cod', 'checkout_payment_bkash',
      'checkout_payment_nagad',
    ];
    for (final k in knownBoolKeys) {
      _bools.putIfAbsent(
          k, () => (settings[k] ?? 'false').toLowerCase() == 'true');
    }

    // Pull select values from the server if we registered defaults for
    // them; the registered default acts as the fallback when the server
    // hasn't stored a value yet.
    for (final k in _selects.keys.toList()) {
      final fromServer = settings[k];
      if (fromServer != null && fromServer.isNotEmpty) {
        _selects[k] = fromServer;
      }
    }
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

  // ─── build() — opinionated frame every settings screen reuses ────────────

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(adminSettingsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          screenTitle,
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
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                  children: [buildBody(settings)],
                ),
              ),
              Positioned(
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
                    border: Border(
                        top: BorderSide(color: AppColors.slateBorder)),
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
                      if (_dirty.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: AppSpacing.sm),
                          child: Text(
                            '${_dirty.length} unsaved',
                            style: AppTypography.bodySm.copyWith(
                                color: AppColors.outline, fontSize: 12),
                          ),
                        ),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _saving || _dirty.isEmpty
                                ? null
                                : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_dirty.isEmpty
                                ? 'No changes'
                                : 'Save ${_dirty.length} change${_dirty.length == 1 ? '' : 's'}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Section card used for visually grouping form fields. Use within
/// [SettingsFormState.buildBody] to mirror the web admin's card-per-section
/// look.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBackground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySm.copyWith(
                color: AppColors.outline, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md - 2),
          child,
        ],
      ),
    );
  }
}
