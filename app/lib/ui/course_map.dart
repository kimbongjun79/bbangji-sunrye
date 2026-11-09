import 'package:flutter/material.dart' hide Route;
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/store.dart';
import '../services/geo.dart';
import 'map_markers.dart';
import 'theme.dart';

/// 코스의 방문 순서를 번호 마커와 직선 경로로 보여준다(실제 도로 경로 아님).
class CourseMap extends StatefulWidget {
  const CourseMap({super.key, required this.stores, this.start});
  final List<Store> stores;
  final GeoPoint? start;

  @override
  State<CourseMap> createState() => _CourseMapState();
}

class _CourseMapState extends State<CourseMap> {
  final _styles = MarkerStyles();
  final _routeStyle = RouteStyle(Palette.cocoa.withValues(alpha: 0.75), 8, strokeColor: Colors.white, strokeWidth: 2);
  KakaoMapController? _map;
  LabelController? _layer;
  Route? _route;
  int _seq = 0;
  bool _busy = false;
  bool _again = false;

  @override
  void didUpdateWidget(CourseMap old) {
    super.didUpdateWidget(old);
    final changed = old.stores.length != widget.stores.length ||
        Iterable.generate(widget.stores.length).any((i) => old.stores[i].id != widget.stores[i].id) ||
        old.start?.lat != widget.start?.lat ||
        old.start?.lng != widget.start?.lng;
    if (changed) _draw();
  }

  Future<void> _draw() async {
    final map = _map;
    if (map == null) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _drawOnce(map);
      } while (_again && mounted);
    } finally {
      _busy = false;
    }
  }

  Future<void> _drawOnce(KakaoMapController map) async {
    final layer = await map.addLabelLayer('course-${++_seq}', competitionType: CompetitionType.none);
    final points = [for (final s in widget.stores) LatLng(s.lat, s.lng)];
    for (var i = 0; i < widget.stores.length; i++) {
      await layer.addPoi(points[i], style: await _styles.numbered(i + 1), rank: 1000 - i);
    }
    final start = widget.start;
    final path = [if (start != null) LatLng(start.lat, start.lng), ...points];
    if (start != null) await layer.addPoi(LatLng(start.lat, start.lng), style: await _styles.me());
    if (_route != null) await map.routeLayer.removeRoute(_route!);
    _route = path.length >= 2 ? await map.routeLayer.addRoute(path, _routeStyle) : null;
    final old = _layer;
    _layer = layer;
    if (old != null) await map.removeLabelLayer(old);
    if (path.isNotEmpty) {
      await map.moveCamera(path.length == 1
          ? CameraUpdate.newCenterPosition(path.first, zoomLevel: 16)
          : CameraUpdate.fitMapPoints(path, padding: 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.stores.isEmpty ? null : widget.stores.first;
    return KakaoMap(
      option: KakaoMapOption(
        position: first == null ? const LatLng(36.3504, 127.3845) : LatLng(first.lat, first.lng),
        zoomLevel: 14,
      ),
      onMapReady: (c) {
        _map = c;
        _draw();
      },
    );
  }
}
