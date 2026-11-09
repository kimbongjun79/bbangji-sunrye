import 'store.dart';

enum OpenState { open, breakTime, closed, dayOff, unknown }

class OpenStatus {
  const OpenStatus(this.state, this.label);
  final OpenState state;
  final String label;

  bool get isOpen => state == OpenState.open;
}

String _hm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// 등록된 영업시간 기준 상태. 실제 영업 여부(임시휴무 등)를 보장하지 않는다.
OpenStatus openStatusAt(Hours? hours, DateTime now) {
  if (hours == null) return const OpenStatus(OpenState.unknown, '영업시간 미확인');
  final today = now.weekday - 1;
  final yesterday = (today + 6) % 7;
  final minute = now.hour * 60 + now.minute;

  // 전날 영업이 자정을 넘겨 이어지는 경우
  final prev = hours.of(yesterday);
  if (prev != null && prev.closeMin > 24 * 60 && minute < prev.closeMin - 24 * 60) {
    return _within(prev, minute + 24 * 60);
  }

  if (!hours.isKnown(today)) return const OpenStatus(OpenState.unknown, '오늘 영업시간 미확인');
  final day = hours.of(today);
  if (day == null) return const OpenStatus(OpenState.dayOff, '오늘 휴무');
  if (minute < day.openMin) return OpenStatus(OpenState.closed, '영업 전 · ${day.open} 오픈');
  if (minute >= day.closeMin) return const OpenStatus(OpenState.closed, '영업 종료');
  return _within(day, minute);
}

OpenStatus _within(DayHours day, int minute) {
  for (final (start, end) in day.breaks) {
    var s = parseHm(start);
    var e = parseHm(end);
    if (s < day.openMin) s += 24 * 60;
    if (e <= s) e += 24 * 60;
    if (minute >= s && minute < e) return OpenStatus(OpenState.breakTime, '브레이크타임 · $end 재개');
  }
  if (minute >= day.closeMin) return const OpenStatus(OpenState.closed, '영업 종료');
  final lastOrder = day.lastOrder == null ? '' : ' · 라스트오더 ${day.lastOrder}';
  return OpenStatus(OpenState.open, '영업 중 · ${_hm(day.closeMin)} 마감$lastOrder');
}

String formatDayHours(DayHours? d) {
  if (d == null) return '휴무';
  final b = d.breaks.isEmpty ? '' : '\n브레이크 ${d.breaks.map((x) => '${x.$1}~${x.$2}').join(', ')}';
  final lo = d.lastOrder == null ? '' : '\n라스트오더 ${d.lastOrder}';
  return '${d.open} ~ ${d.close}$b$lo';
}
