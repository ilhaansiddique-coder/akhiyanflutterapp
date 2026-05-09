import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';

/// Advanced date range picker matching Stripe / Shopify / Plausible style:
/// preset list on the left, dual-month calendar on the right, read-only
/// start/end labels, Cancel/Apply at the bottom.
///
/// On phones (`width < 600`), opens as a full-screen sheet with the presets
/// stacked above a single-month calendar. On wider screens, opens as a
/// centered dialog with two months side-by-side.
///
/// Returns the chosen [DateTimeRange] or `null` if the user cancels.
Future<DateTimeRange?> showAdvancedDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final isPhone = MediaQuery.sizeOf(context).width < 600;
  final first = firstDate ?? DateTime(2000);
  final last = lastDate ?? DateTime.now();
  final initial = initialRange ??
      DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 29)),
        end: DateTime.now(),
      );

  if (isPhone) {
    return showModalBottomSheet<DateTimeRange?>(
      context: context,
      isScrollControlled: true,
      // Transparent so we can paint our own inset, fully-rounded card inside
      // the builder. This lets the dashboard show through on all four sides
      // around the sheet (matches the design spec).
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => Padding(
        // Inset the whole sheet from screen edges + lift above keyboard.
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.md,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            // Cap height so on tiny phones (or landscape) the sheet can't
            // exceed the screen. Content normally sizes much smaller than
            // this and the sheet will hug it.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
            ),
            // Rounded on all four corners (no longer flush to bottom edge),
            // clipping the picker so its inkwell ripples don't leak past
            // the corner radius.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xLarge),
              child: Material(
                color: AppColors.surfaceContainerLowest,
                child: _AdvancedDateRangePicker(
                  initial: initial,
                  firstDate: first,
                  lastDate: last,
                  fullScreen: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  return showDialog<DateTimeRange?>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: _AdvancedDateRangePicker(
          initial: initial,
          firstDate: first,
          lastDate: last,
          fullScreen: false,
        ),
      ),
    ),
  );
}

// ─── Presets ──────────────────────────────────────────────────────────────

enum _Preset {
  today,
  yesterday,
  last7,
  thisMonth,
  last30,
  thisYear,
  lastMonth,
  last90,
  allTime,
  custom,
}

/// Visible-in-grid presets, in display order. `custom` is omitted from the
/// grid because it isn't directly selectable — it appears automatically when
/// the chosen range doesn't match any preset.
const List<_Preset> _gridPresets = <_Preset>[
  _Preset.today,
  _Preset.yesterday,
  _Preset.last7,
  _Preset.thisMonth,
  _Preset.last30,
  _Preset.thisYear,
  _Preset.lastMonth,
  _Preset.last90,
  _Preset.allTime,
];

extension on _Preset {
  String get label {
    switch (this) {
      case _Preset.today:
        return 'Today';
      case _Preset.yesterday:
        return 'Yesterday';
      case _Preset.last7:
        return 'Last 7 days';
      case _Preset.last30:
        return 'Last 30 days';
      case _Preset.last90:
        return 'Last 90 days';
      case _Preset.thisMonth:
        return 'This Month';
      case _Preset.lastMonth:
        return 'Last Month';
      case _Preset.thisYear:
        return 'This Year';
      case _Preset.allTime:
        return 'All Time';
      case _Preset.custom:
        return 'Custom';
    }
  }

  /// Returns the date range this preset represents, or `null` for [custom].
  ///
  /// [firstDate] is required for `allTime`, which spans `[firstDate, today]`.
  DateTimeRange? rangeFor(DateTime now, DateTime firstDate) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _Preset.today:
        return DateTimeRange(start: today, end: today);
      case _Preset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: y, end: y);
      case _Preset.last7:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _Preset.last30:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case _Preset.last90:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 89)),
          end: today,
        );
      case _Preset.thisMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month),
          end: today,
        );
      case _Preset.lastMonth:
        final firstOfThis = DateTime(today.year, today.month);
        final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: DateTime(lastOfPrev.year, lastOfPrev.month),
          end: lastOfPrev,
        );
      case _Preset.thisYear:
        return DateTimeRange(
          start: DateTime(today.year),
          end: today,
        );
      case _Preset.allTime:
        return DateTimeRange(
          start: DateTime(firstDate.year, firstDate.month, firstDate.day),
          end: today,
        );
      case _Preset.custom:
        return null;
    }
  }
}

DateTime _dateOnlyFn(DateTime d) => DateTime(d.year, d.month, d.day);

/// Returns the human-readable label of the preset that exactly matches the
/// given [range], or `'Custom'` if no preset matches. Used by the dashboard
/// pill to show a compact preset name instead of the full `start → end`
/// string.
///
/// [firstDate] must match the value passed to [showAdvancedDateRangePicker]
/// so the `'All Time'` preset is detected consistently across both surfaces.
String dateRangePresetLabel(DateTimeRange range, {required DateTime firstDate}) {
  final s = _dateOnlyFn(range.start);
  final e = _dateOnlyFn(range.end);
  final now = DateTime.now();
  for (final p in _gridPresets) {
    final r = p.rangeFor(now, firstDate);
    if (r != null && _dateOnlyFn(r.start) == s && _dateOnlyFn(r.end) == e) {
      return p.label;
    }
  }
  return 'Custom';
}

// ─── Picker body ──────────────────────────────────────────────────────────

class _AdvancedDateRangePicker extends StatefulWidget {
  const _AdvancedDateRangePicker({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.fullScreen,
  });

  final DateTimeRange initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool fullScreen;

  @override
  State<_AdvancedDateRangePicker> createState() =>
      _AdvancedDateRangePickerState();
}

class _AdvancedDateRangePickerState extends State<_AdvancedDateRangePicker> {
  late DateTime _start;
  late DateTime _end;
  // Anchor of the left-most month being displayed.
  late DateTime _visibleMonth;
  _Preset _activePreset = _Preset.custom;
  // First tap of the next selection cycle. When null, the next tap
  // sets a new start (resetting the range).
  DateTime? _pendingAnchor;

  @override
  void initState() {
    super.initState();
    _start = _dateOnly(widget.initial.start);
    _end = _dateOnly(widget.initial.end);
    _visibleMonth = DateTime(_start.year, _start.month);
    _activePreset = _detectPreset(_start, _end);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  _Preset _detectPreset(DateTime s, DateTime e) {
    final now = DateTime.now();
    for (final p in _gridPresets) {
      final r = p.rangeFor(now, widget.firstDate);
      if (r != null &&
          _dateOnly(r.start) == s &&
          _dateOnly(r.end) == e) {
        return p;
      }
    }
    return _Preset.custom;
  }

  void _applyPreset(_Preset p) {
    final r = p.rangeFor(DateTime.now(), widget.firstDate);
    if (r == null) {
      setState(() => _activePreset = _Preset.custom);
      return;
    }
    setState(() {
      _start = _dateOnly(r.start);
      _end = _dateOnly(r.end);
      _activePreset = p;
      _pendingAnchor = null;
      // Jump calendar to show the start month (and the month after).
      _visibleMonth = DateTime(_start.year, _start.month);
    });
  }

  void _onDayTap(DateTime day) {
    final d = _dateOnly(day);
    if (d.isBefore(_dateOnly(widget.firstDate)) ||
        d.isAfter(_dateOnly(widget.lastDate))) {
      return;
    }
    setState(() {
      if (_pendingAnchor == null) {
        // Start a fresh selection cycle.
        _pendingAnchor = d;
        _start = d;
        _end = d;
      } else {
        // Second tap completes the range; auto-sort.
        final a = _pendingAnchor!;
        if (d.isBefore(a)) {
          _start = d;
          _end = a;
        } else {
          _start = a;
          _end = d;
        }
        _pendingAnchor = null;
      }
      _activePreset = _detectPreset(_start, _end);
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = widget.fullScreen;
    return Material(
      color: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPhone)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Header
            Row(
              children: [
                Text(
                  isPhone ? 'Select date' : 'Select date range',
                  style: context.h3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBackground,
                  ),
                ),
                const Spacer(),
                if (isPhone)
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isPhone) ...[
              _buildPhoneLayout(),
              const SizedBox(height: AppSpacing.sm),
              _buildPhoneBottom(),
              const SizedBox(height: AppSpacing.sm),
            ] else ...[
              Expanded(child: _buildDesktopLayout()),
              const SizedBox(height: AppSpacing.md),
              _buildRangeLabels(),
              const SizedBox(height: AppSpacing.md),
              _buildActions(),
            ],
          ],
        ),
      ),
    );
  }

  /// Phone-only bottom row: compact "May 9 — May 9" range text on the left,
  /// Reset (outlined) + Done (filled) on the right. Matches the design spec
  /// in the dashboard mock.
  Widget _buildPhoneBottom() {
    final fmt = DateFormat('MMM d');
    final rangeText = _start == _end
        ? fmt.format(_start)
        : '${fmt.format(_start)} — ${fmt.format(_end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            rangeText,
            style: context.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // Reset the in-picker selection back to today (the dashboard
                  // default). User still has to tap Done to apply.
                  setState(() {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    _start = today;
                    _end = today;
                    _pendingAnchor = null;
                    _visibleMonth = DateTime(today.year, today.month);
                    _activePreset = _detectPreset(_start, _end);
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryFixed,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  'Reset',
                  style: context.bodyMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  DateTimeRange(
                    start: _start,
                    end: DateTime(
                      _end.year,
                      _end.month,
                      _end.day,
                      23,
                      59,
                      59,
                      999,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  'Done',
                  style: context.bodyMd.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 280, child: _buildPresets(columns: 3)),
        const SizedBox(width: AppSpacing.md),
        Container(
          width: 1,
          color: AppColors.outlineVariant,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildCalendar(monthsToShow: 1)),
      ],
    );
  }

  Widget _buildPhoneLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhonePresetPills(),
        const SizedBox(height: AppSpacing.sm),
        // Calendar wrapped in a soft card so it visually groups apart from
        // the presets and the action buttons. Sized to content (no empty
        // tail) thanks to `fillHeight: false` below. Outer `margin` adds
        // breathing room on all four sides so the card floats inside the
        // sheet rather than touching the presets / buttons.
        Container(
          // Horizontal margin only — vertical breathing room comes from the
          // SizedBox spacers above (in _buildPhoneLayout) and below (in the
          // outer build), so we don't double up.
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xLarge),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: _buildCalendar(monthsToShow: 1, fillHeight: false),
        ),
      ],
    );
  }

  /// Pill-shaped, free-flow preset chips for the phone bottom-sheet — no
  /// "PRESETS" label, no fixed grid. Order mirrors the dashboard mock.
  Widget _buildPhonePresetPills() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final p in _gridPresets)
          _PresetChip(
            label: p.label,
            active: _activePreset == p,
            onTap: () => _applyPreset(p),
            pill: true,
          ),
      ],
    );
  }

  /// Renders the preset chips as a tidy grid with a small "PRESETS" label
  /// above. The grid sizes itself to its content so it doesn't fight the
  /// surrounding column for vertical space.
  Widget _buildPresets({required int columns}) {
    const gap = AppSpacing.xs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.xs),
          child: Text(
            'PRESETS',
            style: context.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalGap = gap * (columns - 1);
            final cellW = (constraints.maxWidth - totalGap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final p in _gridPresets)
                  SizedBox(
                    width: cellW,
                    child: _PresetChip(
                      label: p.label,
                      active: _activePreset == p,
                      onTap: () => _applyPreset(p),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCalendar({required int monthsToShow, bool fillHeight = true}) {
    final months = <DateTime>[
      for (var i = 0; i < monthsToShow; i++)
        DateTime(_visibleMonth.year, _visibleMonth.month + i),
    ];
    final daysRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < months.length; i++) ...[
          Expanded(
            child: _MonthGrid(
              month: months[i],
              rangeStart: _start,
              rangeEnd: _end,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onDayTap: _onDayTap,
            ),
          ),
          if (i < months.length - 1)
            const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Month nav header
        Row(
          children: [
            _NavButton(
              icon: Icons.chevron_left,
              onTap: _canGoPrev() ? () => _shiftMonth(-1) : null,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final m in months)
                    Text(
                      DateFormat('MMMM yyyy').format(m),
                      style: context.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBackground,
                      ),
                    ),
                ],
              ),
            ),
            _NavButton(
              icon: Icons.chevron_right,
              onTap: _canGoNext(monthsToShow) ? () => _shiftMonth(1) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // On phone we want the grid to size to its (intrinsic) content so the
        // sheet hugs the calendar — no empty space below. On desktop we keep
        // Expanded so the dialog body fills its fixed maxHeight.
        if (fillHeight) Expanded(child: daysRow) else daysRow,
      ],
    );
  }

  bool _canGoPrev() {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    return !prev.isBefore(DateTime(widget.firstDate.year,
        widget.firstDate.month));
  }

  bool _canGoNext(int monthsToShow) {
    final lastShown =
        DateTime(_visibleMonth.year, _visibleMonth.month + monthsToShow);
    final cap = DateTime(widget.lastDate.year, widget.lastDate.month + 1);
    return lastShown.isBefore(cap);
  }

  Widget _buildRangeLabels() {
    final fmt = DateFormat('MMM d, y');
    return Row(
      children: [
        Expanded(
          child: _RangeField(label: 'Start', value: fmt.format(_start)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _RangeField(label: 'End', value: fmt.format(_end)),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            // Expand `end` to end-of-day so a single-day selection ("Today",
            // "Yesterday", or two taps on the same date) is a real 24h window
            // instead of a zero-width range. Backend filters with `lte: end`,
            // so this lets it include the whole final day.
            DateTimeRange(
              start: _start,
              end: DateTime(
                _end.year,
                _end.month,
                _end.day,
                23,
                59,
                59,
                999,
              ),
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ─── Preset chip ──────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.pill = false,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// When `true`, renders as a fully-rounded pill (active = solid orange,
  /// idle = neutral grey-blue). Used by the phone bottom-sheet to match the
  /// dashboard date-picker mock.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    if (pill) {
      final bg = active ? AppColors.primary : AppColors.backgroundAlt;
      final fg = active ? AppColors.onPrimary : AppColors.onBackground;
      return Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            child: Text(
              label,
              style: context.bodySm.copyWith(
                color: fg,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // The codebase's `primaryContainer` token is the dark brand surface, so
    // for an active *light* tint we use `primaryFixed` (light lavender), which
    // is the project's actual M3 light-container color.
    final bg = active ? AppColors.primaryFixed : AppColors.surfaceContainerLowest;
    final fg = active ? AppColors.onPrimaryFixed : AppColors.onBackground;
    final border =
        active ? AppColors.primary : AppColors.outlineVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.bodySm.copyWith(
              color: fg,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Month grid ───────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.rangeStart,
    required this.rangeEnd,
    required this.firstDate,
    required this.lastDate,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDayTap;

  // Fixed cell count keeps the calendar card a constant height regardless
  // of whether the month spans 4, 5, or 6 weeks. 6 rows × 7 cols is the
  // worst case (e.g. a month that starts on Sunday and has 31 days).
  static const int _totalCells = 6 * 7;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    // DateTime.weekday returns Mon=1 ... Sun=7. We render Mon-first to match
    // the design spec (matches the dashboard date-picker mock).
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7; // Mon=0, ..., Sun=6
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    final daysInPrevMonth =
        DateTime(month.year, month.month, 0).day; // day 0 of this month = last day prev

    final firstCap = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final lastCap = DateTime(lastDate.year, lastDate.month, lastDate.day);

    return Column(
      children: [
        // Weekday headers (Mon-first, two-letter caps).
        Row(
          children: [
            for (final d in const ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: context.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Day grid — always 6 rows.
        for (var row = 0; row < _totalCells / 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(
                    index: row * 7 + col,
                    leadingBlanks: leadingBlanks,
                    daysInMonth: daysInMonth,
                    daysInPrevMonth: daysInPrevMonth,
                    firstCap: firstCap,
                    lastCap: lastCap,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell({
    required int index,
    required int leadingBlanks,
    required int daysInMonth,
    required int daysInPrevMonth,
    required DateTime firstCap,
    required DateTime lastCap,
  }) {
    final dayNum = index - leadingBlanks + 1;
    // Leading cell from previous month — render the actual date number in a
    // muted color, no band, no tap. Keeps the card height constant and
    // matches the design spec.
    if (dayNum < 1) {
      final prevDayNum = daysInPrevMonth + dayNum; // dayNum is 0 or negative
      return SizedBox(
        height: 36,
        child: Center(
          child: Text(
            '$prevDayNum',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.outlineVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    // Trailing cell from next month — same treatment.
    if (dayNum > daysInMonth) {
      final nextDayNum = dayNum - daysInMonth;
      return SizedBox(
        height: 36,
        child: Center(
          child: Text(
            '$nextDayNum',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.outlineVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    final date = DateTime(month.year, month.month, dayNum);
    final isStart = date == rangeStart;
    final isEnd = date == rangeEnd;
    final inRange = !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
    final isEndpoint = isStart || isEnd;
    final isSingleDay = isStart && isEnd;
    final disabled = date.isBefore(firstCap) || date.isAfter(lastCap);

    // Two-half band painting:
    //   • middle in-range cell  → both halves filled  → continuous strip
    //   • start cell            → only right half     → strip points right
    //   • end cell              → only left half      → strip arrives from left
    //   • single-day selection  → no band, just the circle
    final showLeftHalf = inRange && !isStart && !isSingleDay;
    final showRightHalf = inRange && !isEnd && !isSingleDay;
    final bandColor = AppColors.primary.withValues(alpha: 0.12);

    // Foreground text color.
    Color fg;
    FontWeight weight;
    if (disabled) {
      fg = AppColors.outline;
      weight = FontWeight.w500;
    } else if (isEndpoint) {
      fg = AppColors.onPrimary;
      weight = FontWeight.w700;
    } else if (inRange) {
      fg = AppColors.onBackground;
      weight = FontWeight.w600;
    } else {
      fg = AppColors.onBackground;
      weight = FontWeight.w500;
    }

    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          // Layer 1: peach band (split into left/right halves so adjacent
          // cells join into a continuous strip with no gaps).
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: showLeftHalf ? bandColor : Colors.transparent,
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: showRightHalf ? bandColor : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
          // Layer 2: solid orange endpoint circle, sitting on top of the band.
          if (isEndpoint && !disabled)
            const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          // Layer 3: tap target + day number text, on top of everything.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: disabled ? null : () => onDayTap(date),
                child: Center(
                  child: Text(
                    '$dayNum',
                    style: AppTypography.bodySm.copyWith(
                      color: fg,
                      fontWeight: weight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Misc ─────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: onTap == null
          ? AppColors.outlineVariant
          : AppColors.onSurfaceVariant,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RangeField extends StatelessWidget {
  const _RangeField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        color: AppColors.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.bodyMd.copyWith(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
