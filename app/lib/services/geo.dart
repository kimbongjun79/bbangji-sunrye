import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// 두 좌표 사이의 대원 거리(m).
double distanceMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

double _rad(double d) => d * math.pi / 180;

String formatDistance(double meters) =>
    meters < 1000 ? '${meters.round()}m' : '${(meters / 1000).toStringAsFixed(1)}km';

/// 방문 순서 추천(직선거리 기준). 출발점 [start]에서 [stops]를 모두 거치는 경로 길이를 줄인다.
/// [fixLastIndex]가 주어지면 stops의 해당 지점을 마지막 목적지로 고정한다.
/// 반환값은 stops 인덱스의 방문 순서.
List<int> optimizeVisitOrder(GeoPoint start, List<GeoPoint> stops, {int? fixLastIndex}) {
  final n = stops.length;
  if (n <= 1) return List.generate(n, (i) => i);

  // 0 = start, 1..n = stops
  final pts = [start, ...stops];
  final dist = List.generate(n + 1, (i) => List.generate(n + 1, (j) => distanceMeters(pts[i], pts[j])));
  final last = fixLastIndex == null ? null : fixLastIndex + 1;

  double length(List<int> route) {
    var sum = dist[0][route.first];
    for (var i = 0; i + 1 < route.length; i++) {
      sum += dist[route[i]][route[i + 1]];
    }
    return sum;
  }

  List<int> best;
  if (n <= 8) {
    // 8! = 40320: 완전 탐색으로 최적해.
    final free = [for (var i = 1; i <= n; i++) if (i != last) i];
    best = [...free, ?last];
    var bestLen = length(best);
    void permute(List<int> cur, List<bool> used) {
      if (cur.length == free.length) {
        final route = [...cur, ?last];
        final len = length(route);
        if (len < bestLen) {
          bestLen = len;
          best = route;
        }
        return;
      }
      for (var i = 0; i < free.length; i++) {
        if (used[i]) continue;
        used[i] = true;
        cur.add(free[i]);
        permute(cur, used);
        cur.removeLast();
        used[i] = false;
      }
    }

    permute([], List.filled(free.length, false));
  } else {
    // 최근접 이웃 + 2-opt 개선.
    final remaining = {for (var i = 1; i <= n; i++) if (i != last) i};
    final route = <int>[];
    var cur = 0;
    while (remaining.isNotEmpty) {
      final next = remaining.reduce((a, b) => dist[cur][a] <= dist[cur][b] ? a : b);
      route.add(next);
      remaining.remove(next);
      cur = next;
    }
    if (last != null) route.add(last);
    final movable = last == null ? route.length : route.length - 1;
    var improved = true;
    while (improved) {
      improved = false;
      for (var i = 0; i < movable - 1; i++) {
        for (var k = i + 1; k < movable; k++) {
          final candidate = [...route.sublist(0, i), ...route.sublist(i, k + 1).reversed, ...route.sublist(k + 1)];
          if (length(candidate) + 1e-6 < length(route)) {
            route
              ..clear()
              ..addAll(candidate);
            improved = true;
          }
        }
      }
    }
    best = route;
  }
  return [for (final i in best) i - 1];
}

/// 출발점부터 순서대로 이동하는 직선거리 합계(m).
double routeLength(GeoPoint start, List<GeoPoint> ordered) {
  var sum = 0.0;
  var prev = start;
  for (final p in ordered) {
    sum += distanceMeters(prev, p);
    prev = p;
  }
  return sum;
}
