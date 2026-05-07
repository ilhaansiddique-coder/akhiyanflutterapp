import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

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
    return Navigator.of(context).push<DateTimeRange?>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (ctx, _, _) => _AdvancedDateRangePicker(
          initial: initial,
          firstDate: first,
          lastDate: last,
          fullScreen: true,
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
          start: DateTime(today.year, today.month, 1),
          end: today,
        );
      case _Preset.lastMonth:
        final firstOfThis = DateTime(today.year, today.month, 1);
        final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: DateTime(lastOfPrev.year, lastOfPrev.month, 1),
          end: lastOfPrev,
        );
      case _Preset.thisYear:
        return DateTimeRange(
          start: DateTime(today.year, 1, 1),
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
    _visibleMonth = DateTime(_start.year, _start.month, 1);
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
      _visibleMonth = DateTime(_start.year, _start.month, 1);
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
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = widget.fullScreen;
    return Material(
      color: AppColors.surfaceContainerLowest,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Select date range',
                    style: AppTypography.h3.copyWith(
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
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: isPhone
                    ? _buildPhoneLayout()
                    : _buildDesktopLayout(),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildRangeLabels(),
              const SizedBox(height: AppSpacing.md),
              _buildActions(),
            ],
          ),
        ),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPresets(columns: 2),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: _buildCalendar(monthsToShow: 1)),
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
            style: AppTypography.caption.copyWith(
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

  Widget _buildCalendar({required int monthsToShow}) {
    final months = <DateTime>[
      for (var i = 0; i < monthsToShow; i++)
        DateTime(_visibleMonth.year, _visibleMonth.month + i, 1),
    ];
    return Column(
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
                      style: AppTypography.bodyMd.copyWith(
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
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < months.length; i++) ...[
                Expanded(child: _MonthGrid(
                  month: months[i],
                  rangeStart: _start,
                  rangeEnd: _end,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDayTap: _onDayTap,
                )),
                if (i < months.length - 1)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _canGoPrev() {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    return !prev.isBefore(DateTime(widget.firstDate.year,
        widget.firstDate.month, 1));
  }

  bool _canGoNext(int monthsToShow) {
    final lastShown =
        DateTime(_visibleMonth.year, _visibleMonth.month + monthsToShow, 1);
    final cap = DateTime(widget.lastDate.year, widget.lastDate.month + 1, 1);
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
          onPressed: () => Navigator.of(context).pop(null),
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
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            style: AppTypography.bodySm.copyWith(
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

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Monday=1 ... Sunday=7. We render Sun-first to match BD/US convention.
    final leadingBlanks = firstOfMonth.weekday % 7; // Sun=0, Mon=1, ...
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    final totalCells =
        ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    final firstCap = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final lastCap = DateTime(lastDate.year, lastDate.month, lastDate.day);

    return Column(
      children: [
        // Weekday headers
        Row(
          children: [
            for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Day grid
        for (var row = 0; row < totalCells / 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(
                    index: row * 7 + col,
                    leadingBlanks: leadingBlanks,
                    daysInMonth: daysInMonth,
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
    required DateTime firstCap,
    required DateTime lastCap,
  }) {
    final dayNum = index - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 36);
    }
    final date = DateTime(month.year, month.month, dayNum);
    final isStart = date == rangeStart;
    final isEnd = date == rangeEnd;
    final inRange = !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
    final isEndpoint = isStart || isEnd;
    final disabled = date.isBefore(firstCap) || date.isAfter(lastCap);

    Color? bg;
    Color fg = AppColors.onBackground;
    FontWeight weight = FontWeight.w500;
    if (disabled) {
      fg = AppColors.outline;
    } else if (isEndpoint) {
      bg = AppColors.primary;
      fg = AppColors.onPrimary;
      weight = FontWeight.w700;
    } else if (inRange) {
      // Light lavender tint — see `_PresetChip` note on container token usage.
      bg = AppColors.primaryFixed;
      fg = AppColors.onPrimaryFixed;
      weight = FontWeight.w600;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: bg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          onTap: disabled ? null : () => onDayTap(date),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: SizedBox(
            height: 36,
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
            style: AppTypography.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
