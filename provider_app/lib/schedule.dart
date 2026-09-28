import 'package:flutter/material.dart';

import 'data.dart';

/// One working day.
class WorkDay {
  WorkDay({required this.weekday, this.start, this.end});

  /// 0 = Sunday, matching Postgres `extract(dow)`.
  final int weekday;
  final TimeOfDay? start;
  final TimeOfDay? end;

  bool get isWorking => start != null && end != null;

  static const names = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday',
  ];

  String get name => names[weekday];
  String get shortName => name.substring(0, 3);

  String get hours => isWorking
      ? '${_fmt(start!)} – ${_fmt(end!)}'
      : 'Not working';

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  WorkDay copyWith({TimeOfDay? start, TimeOfDay? end, bool clear = false}) =>
      clear
          ? WorkDay(weekday: weekday)
          : WorkDay(
              weekday: weekday,
              start: start ?? this.start,
              end: end ?? this.end,
            );
}

class ScheduleApi {
  /// The week, with a row for every day whether or not it is worked.
  ///
  /// An empty schedule is meaningful: it means no restriction at all, which is
  /// how every provider behaves until they open this screen.
  static Future<List<WorkDay>> myWeek() async {
    final me = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('provider_availability')
        .select('weekday, starts_at, ends_at')
        .eq('provider_id', me);

    final byDay = <int, WorkDay>{};
    for (final r in rows) {
      final d = (r['weekday'] as num).toInt();
      byDay[d] = WorkDay(
        weekday: d,
        start: _parse(r['starts_at'] as String),
        end: _parse(r['ends_at'] as String),
      );
    }

    // Monday first: nobody thinks of their working week as starting on Sunday.
    const order = [1, 2, 3, 4, 5, 6, 0];
    return [for (final d in order) byDay[d] ?? WorkDay(weekday: d)];
  }

  static Future<bool> hasAnyHours() async {
    final me = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('provider_availability')
        .select('weekday')
        .eq('provider_id', me)
        .limit(1);
    return rows.isNotEmpty;
  }

  static Future<void> setDay(WorkDay day) async {
    final me = supabase.auth.currentUser!.id;

    if (!day.isWorking) {
      await supabase
          .from('provider_availability')
          .delete()
          .eq('provider_id', me)
          .eq('weekday', day.weekday);
      return;
    }

    await supabase.from('provider_availability').upsert({
      'provider_id': me,
      'weekday': day.weekday,
      'starts_at': '${WorkDay._fmt(day.start!)}:00',
      'ends_at': '${WorkDay._fmt(day.end!)}:00',
    }, onConflict: 'provider_id,weekday');
  }

  /// Clears the whole schedule, which returns the account to "always
  /// available" rather than "never available".
  static Future<void> clearAll() async {
    final me = supabase.auth.currentUser!.id;
    await supabase.from('provider_availability').delete().eq('provider_id', me);
  }

  static TimeOfDay _parse(String hhmmss) {
    final parts = hhmmss.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}
