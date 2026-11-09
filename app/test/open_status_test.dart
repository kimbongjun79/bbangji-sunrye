import 'package:bbangji_sunrye/models/open_status.dart';
import 'package:bbangji_sunrye/models/store.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-09은 월요일.
DateTime mon(int h, int m) => DateTime(2026, 11, 9, h, m);
DateTime tue(int h, int m) => DateTime(2026, 11, 10, h, m);

void main() {
  final hours = Hours.fromJson({
    'mon': {
      'open': '10:00',
      'close': '21:00',
      'breaks': [
        ['15:00', '16:00'],
      ],
      'lastOrder': '20:30',
    },
    'tue': null,
    'fri': {'open': '18:00', 'close': '02:00'},
  });

  test('영업시간 안이면 영업 중', () {
    expect(openStatusAt(hours, mon(12, 0)).state, OpenState.open);
  });

  test('오픈 전·마감 시각 경계', () {
    expect(openStatusAt(hours, mon(9, 59)).state, OpenState.closed);
    expect(openStatusAt(hours, mon(10, 0)).state, OpenState.open);
    expect(openStatusAt(hours, mon(20, 59)).state, OpenState.open);
    expect(openStatusAt(hours, mon(21, 0)).state, OpenState.closed);
  });

  test('브레이크타임은 영업 중이 아님', () {
    expect(openStatusAt(hours, mon(15, 30)).state, OpenState.breakTime);
    expect(openStatusAt(hours, mon(16, 0)).state, OpenState.open);
  });

  test('휴무일·미확인 요일 구분', () {
    expect(openStatusAt(hours, tue(12, 0)).state, OpenState.dayOff);
    expect(openStatusAt(hours, DateTime(2026, 11, 11, 12)).state, OpenState.unknown); // 수요일 키 없음
    expect(openStatusAt(null, mon(12, 0)).state, OpenState.unknown);
  });

  test('자정을 넘기는 영업은 다음날 새벽까지 영업 중', () {
    final fri = DateTime(2026, 11, 13, 23, 0);
    final satEarly = DateTime(2026, 11, 14, 1, 30);
    final satAfter = DateTime(2026, 11, 14, 2, 0);
    expect(openStatusAt(hours, fri).state, OpenState.open);
    expect(openStatusAt(hours, satEarly).state, OpenState.open);
    // 토요일 키가 없으므로 새벽 영업이 끝나면 미확인.
    expect(openStatusAt(hours, satAfter).state, OpenState.unknown);
  });
}
