import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../schedule.dart';

/// Working hours.
///
/// These are enforced by the database, not by the app: outside them a
/// professional simply does not appear in search. That makes this screen
/// load-bearing rather than a preference pane, so it says plainly what each
/// choice will do.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<WorkDay> _week = [];
  bool _loading = true;
  bool _anyHours = false;

  static const _names = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results =
          await Future.wait([ScheduleApi.myWeek(), ScheduleApi.hasAnyHours()]);
      if (!mounted) return;
      setState(() {
        _week = results[0] as List<WorkDay>;
        _anyHours = results[1] as bool;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(WorkDay day) async {
    final result = await showYaariSheet<WorkDay>(
      context,
      child: _DaySheet(day: day, name: _names[day.weekday == 0 ? 6 : day.weekday - 1]),
    );
    if (result == null) return;
    try {
      await ScheduleApi.setDay(result);
      Buzz.pick();
      await _load();
    } catch (_) {
      if (mounted) Buzz.reject();
    }
  }

  Future<void> _clearAll() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Surface.canvas,
        title: const Text('Available at any time?'),
        content: const Text(
            'Clearing your hours means customers can find you around the '
            'clock, whenever you are online.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Keep my hours')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (sure != true) return;
    await ScheduleApi.clearAll();
    Buzz.pick();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Surface.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: ListView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 120),
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.md, bottom: 5),
                child: Text('Your hours', style: Txt.hero),
              ),
            ),
            Text(
              _anyHours
                  ? 'Customers only see you inside these hours.'
                  : 'No hours set, so customers can find you at any time you '
                      'are online.',
              style: Txt.body,
            ),
            const SizedBox(height: Gap.xl),

            if (_loading)
              ...List.generate(
                  7,
                  (_) => const Padding(
                        padding: EdgeInsets.only(bottom: Gap.md),
                        child: Skeleton(height: 66, radius: Radii.card),
                      ))
            else ...[
              for (var i = 0; i < _week.length; i++) ...[
                Reveal(
                  delay: Duration(milliseconds: 40 * i),
                  child: _DayRow(
                    name: _names[_week[i].weekday == 0 ? 6 : _week[i].weekday - 1],
                    day: _week[i],
                    onTap: () => _edit(_week[i]),
                  ),
                ),
                const SizedBox(height: Gap.md),
              ],
              const SizedBox(height: Gap.sm),
              if (_anyHours)
                Btn('Available at any time',
                    kind: BtnKind.ghost, onTap: _clearAll),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.name, required this.day, required this.onTap});

  final String name;
  final WorkDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final working = day.start != null && day.end != null;

    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: working ? Brand.c50 : Coal.c50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(name.substring(0, 3).toUpperCase(),
                style: Txt.label.copyWith(
                    fontSize: 9.5,
                    color: working ? Brand.c600 : Coal.c400)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Txt.cardTitle.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  working
                      ? '${_fmt(day.start!)} — ${_fmt(day.end!)}'
                      : 'Not working',
                  style: Txt.meta.copyWith(
                      color: working ? Signal.success : Coal.c400,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Coal.c400),
        ],
      ),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Setting one day's hours.
class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.day, required this.name});

  final WorkDay day;
  final String name;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late TimeOfDay? _start = widget.day.start;
  late TimeOfDay? _end = widget.day.end;

  /// Whole hours only. Nobody sets their working day to 08:17, and a wheel
  /// picker for minutes is three taps where one will do.
  static const _hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];

  @override
  Widget build(BuildContext context) {
    final working = _start != null && _end != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHead(
            title: widget.name,
            subtitle: 'Customers can only find you inside these hours'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            children: [
              Panel(
                onTap: () => setState(() {
                  Buzz.tap();
                  _start = null;
                  _end = null;
                }),
                padding: const EdgeInsets.all(Gap.lg),
                shadow: !working ? Shade.tinted(Brand.c500) : Shade.sm,
                border: Border.all(
                    color: !working ? Brand.c500 : Colors.transparent,
                    width: 2),
                child: Row(children: [
                  const Icon(Icons.bedtime_rounded, size: 17, color: Coal.c500),
                  const SizedBox(width: Gap.md),
                  Expanded(
                      child: Text('Not working',
                          style: Txt.cardTitle.copyWith(fontSize: 14))),
                  if (!working)
                    const Icon(Icons.check_circle_rounded,
                        size: 20, color: Brand.c500),
                ]),
              ),
              const SizedBox(height: Gap.xl),
              Text('STARTS', style: Txt.label),
              const SizedBox(height: Gap.sm),
              _HourPicker(
                value: _start,
                onPick: (t) => setState(() {
                  Buzz.tap();
                  _start = t;
                  // Keep the day valid: an end before the start would be
                  // rejected by the database anyway.
                  if (_end == null || _end!.hour <= t.hour) {
                    _end = TimeOfDay(hour: (t.hour + 8).clamp(0, 23), minute: 0);
                  }
                }),
              ),
              const SizedBox(height: Gap.xl),
              Text('ENDS', style: Txt.label),
              const SizedBox(height: Gap.sm),
              _HourPicker(
                value: _end,
                min: _start?.hour,
                onPick: (t) => setState(() {
                  Buzz.tap();
                  _end = t;
                  _start ??= const TimeOfDay(hour: 8, minute: 0);
                }),
              ),
              const SizedBox(height: Gap.xxl),
              Btn('Save ${widget.name}',
                  onTap: () => Navigator.pop(
                      context,
                      WorkDay(
                          weekday: widget.day.weekday,
                          start: _start,
                          end: _end))),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({required this.value, required this.onPick, this.min});

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;
  final int? min;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _DaySheetState._hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          final h = _DaySheetState._hours[i];
          final enabled = min == null || h > min!;
          final selected = value?.hour == h;

          return Pressable(
            onTap: enabled ? () => onPick(TimeOfDay(hour: h, minute: 0)) : null,
            scale: 0.92,
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.settle,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Brand.c500
                    : enabled
                        ? Surface.raised
                        : Coal.c50,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(
                    color: selected ? Brand.c500 : Coal.c100, width: 1.5),
                boxShadow: selected ? Shade.tinted(Brand.c500) : null,
              ),
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: Txt.meta.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : enabled
                          ? Coal.c800
                          : Coal.c300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
