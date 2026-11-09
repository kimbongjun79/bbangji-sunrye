import 'dart:math' as math;

import 'package:bbangji_sunrye/services/geo.dart';
import 'package:flutter_test/flutter_test.dart';

double bruteForceBest(GeoPoint start, List<GeoPoint> pts, {int? fixLast}) {
  var best = double.infinity;
  final idx = [for (var i = 0; i < pts.length; i++) if (i != fixLast) i];
  void perm(List<int> cur, Set<int> used) {
    if (cur.length == idx.length) {
      final order = [...cur, ?fixLast];
      best = math.min(best, routeLength(start, [for (final i in order) pts[i]]));
      return;
    }
    for (final i in idx) {
      if (used.add(i)) {
        perm([...cur, i], used);
        used.remove(i);
      }
    }
  }

  perm([], {});
  return best;
}

List<GeoPoint> randomPoints(int n, int seed) {
  final r = math.Random(seed);
  return [for (var i = 0; i < n; i++) GeoPoint(36.30 + r.nextDouble() * 0.1, 127.33 + r.nextDouble() * 0.1)];
}

void main() {
  const start = GeoPoint(36.3504, 127.3845);

  test('일렬로 놓인 가게는 가까운 순서대로 방문', () {
    final pts = [
      const GeoPoint(36.3504, 127.4145),
      const GeoPoint(36.3504, 127.3945),
      const GeoPoint(36.3504, 127.4045),
    ];
    expect(optimizeVisitOrder(start, pts), [1, 2, 0]);
  });

  test('8곳 이하는 최적해와 같은 거리', () {
    for (var seed = 0; seed < 5; seed++) {
      final pts = randomPoints(7, seed);
      final order = optimizeVisitOrder(start, pts);
      expect(order.toSet(), {for (var i = 0; i < 7; i++) i});
      expect(routeLength(start, [for (final i in order) pts[i]]), closeTo(bruteForceBest(start, pts), 1e-6));
    }
  });

  test('마지막 가게 고정', () {
    final pts = randomPoints(6, 42);
    final order = optimizeVisitOrder(start, pts, fixLastIndex: 2);
    expect(order.last, 2);
    expect(routeLength(start, [for (final i in order) pts[i]]),
        closeTo(bruteForceBest(start, pts, fixLast: 2), 1e-6));
  });

  test('많은 가게는 휴리스틱이지만 모든 가게를 한 번씩 방문하고 입력 순서보다 길지 않음', () {
    final pts = randomPoints(15, 7);
    final order = optimizeVisitOrder(start, pts, fixLastIndex: 3);
    expect(order.length, 15);
    expect(order.toSet().length, 15);
    expect(order.last, 3);
    final identity = [for (var i = 0; i < 15; i++) if (i != 3) i, 3];
    expect(routeLength(start, [for (final i in order) pts[i]]),
        lessThanOrEqualTo(routeLength(start, [for (final i in identity) pts[i]])));
  });
}
