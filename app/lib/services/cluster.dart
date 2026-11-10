import '../models/store.dart';

class Bounds {
  const Bounds({required this.south, required this.west, required this.north, required this.east});
  final double south, west, north, east;

  bool contains(double lat, double lng) => lat >= south && lat <= north && lng >= west && lng <= east;

  /// 가장자리 마커가 잘리지 않도록 비율만큼 넓힌 영역.
  Bounds expand(double ratio) {
    final dLat = (north - south) * ratio;
    final dLng = (east - west) * ratio;
    return Bounds(south: south - dLat, west: west - dLng, north: north + dLat, east: east + dLng);
  }
}

class MarkerGroup {
  MarkerGroup(this.stores, {this.colocated = false});
  final List<Store> stores;

  /// 같은 건물처럼 사실상 같은 위치의 가게 묶음. 확대해도 갈라지지 않으므로 목록으로 보여준다.
  final bool colocated;

  bool get isSingle => stores.length == 1;
  double get lat => stores.map((s) => s.lat).reduce((a, b) => a + b) / stores.length;
  double get lng => stores.map((s) => s.lng).reduce((a, b) => a + b) / stores.length;
}

/// 약 30m 격자(대전 위도 기준). 이 안의 가게는 같은 위치로 본다.
const _sameSpotLat = 0.00027;
const _sameSpotLng = 0.00033;

/// 화면 영역을 격자로 나눠 가까운 가게를 묶는다.
/// 보이는 가게가 [maxSingles] 이하이거나 충분히 확대([zoomLevel] ≥ [singleZoom])하면
/// 같은 위치(약 30m 이내) 가게만 묶는다.
List<MarkerGroup> clusterStores(
  List<Store> stores,
  Bounds view, {
  required int zoomLevel,
  int columns = 5,
  int rows = 8,
  int maxSingles = 60,
  int singleZoom = 17,
}) {
  final area = view.expand(0.15);
  final visible = [for (final s in stores) if (area.contains(s.lat, s.lng)) s];
  if (visible.length <= maxSingles || zoomLevel >= singleZoom) {
    final spots = <(int, int), List<Store>>{};
    for (final s in visible) {
      (spots[((s.lat / _sameSpotLat).floor(), (s.lng / _sameSpotLng).floor())] ??= []).add(s);
    }
    return [for (final g in spots.values) MarkerGroup(g, colocated: g.length > 1)];
  }
  final cellLat = (view.north - view.south) / rows;
  final cellLng = (view.east - view.west) / columns;
  final cells = <(int, int), List<Store>>{};
  for (final s in visible) {
    final key = (((s.lat - area.south) / cellLat).floor(), ((s.lng - area.west) / cellLng).floor());
    (cells[key] ??= []).add(s);
  }
  return [for (final g in cells.values) MarkerGroup(g)];
}
