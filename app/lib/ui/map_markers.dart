import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../models/store.dart';
import 'theme.dart';

/// 지도 마커 스타일. 위젯을 이미지로 그려 캐시한다(스타일 등록은 지도별로 1회).
class MarkerStyles {
  final Map<String, PoiStyle> _cache = {};

  Future<PoiStyle> store(StoreCategory c, {bool selected = false, bool showName = false}) async {
    final key = 'store-${c.key}-$selected-$showName';
    final cached = _cache[key];
    if (cached != null) return cached;
    final size = selected ? 56.0 : 40.0;
    final icon = await KImage.fromWidget(_Pin(color: categoryColor(c), icon: categoryIcon(c), size: size), Size(size, size * 1.25));
    return _cache[key] = PoiStyle(
      icon: icon,
      anchor: const KPoint(0.5, 1.0),
      textStyle: showName || selected
          ? [const PoiTextStyle(size: 26, color: Palette.espresso, stroke: 4, strokeColor: Colors.white)]
          : const [],
    );
  }

  Future<PoiStyle> cluster(int count) async {
    final label = count > 999 ? '999+' : '$count';
    final key = 'cluster-$label';
    final cached = _cache[key];
    if (cached != null) return cached;
    final d = count < 10 ? 40.0 : count < 100 ? 48.0 : 56.0;
    final icon = await KImage.fromWidget(_Cluster(label: label, diameter: d), Size(d, d));
    return _cache[key] = PoiStyle(icon: icon, anchor: const KPoint(0.5, 0.5));
  }

  Future<PoiStyle> numbered(int n) async {
    final key = 'num-$n';
    final cached = _cache[key];
    if (cached != null) return cached;
    final icon = await KImage.fromWidget(_Numbered(n: n), const Size(34, 34));
    return _cache[key] = PoiStyle(icon: icon, anchor: const KPoint(0.5, 0.5));
  }

  Future<PoiStyle> me() async {
    final cached = _cache['me'];
    if (cached != null) return cached;
    final icon = await KImage.fromWidget(const _Me(), const Size(26, 26));
    return _cache['me'] = PoiStyle(icon: icon, anchor: const KPoint(0.5, 0.5));
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon, required this.size});
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: size * 0.08),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.55),
          ),
          CustomPaint(size: Size(size * 0.3, size * 0.25), painter: _TailPainter(color)),
        ]),
      );
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

class _Cluster extends StatelessWidget {
  const _Cluster({required this.label, required this.diameter});
  final String label;
  final double diameter;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.cocoa.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: Palette.butter, width: 3),
          ),
          child: Text(label,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: diameter * 0.32)),
        ),
      );
}

class _Numbered extends StatelessWidget {
  const _Numbered({required this.n});
  final int n;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.cocoa,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      );
}

class _Me extends StatelessWidget {
  const _Me();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F80ED),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Color(0x552F80ED), blurRadius: 6, spreadRadius: 3)],
        ),
      );
}
