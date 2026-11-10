import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:provider/provider.dart';

import '../models/store.dart';
import '../services/cluster.dart';
import '../services/external_links.dart';
import '../services/geo.dart';
import '../state/app_state.dart';
import 'map_markers.dart';
import 'store_detail_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapKey = GlobalKey();
  final _search = TextEditingController();
  final _styles = MarkerStyles();

  KakaoMapController? _map;
  List<Poi> _storePois = const [];
  LabelController? _meLayer;
  Poi? _mePoi;
  int _renderSeq = 0;
  bool _rendering = false;
  bool _renderAgain = false;

  bool _listMode = false;
  Store? _selected;
  GeoPoint _center = daejeonCenter;
  int _zoom = 13;
  String _filterSignature = '';
  String? _mapError;

  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state.addListener(_onStateChanged);
    _filterSignature = _signature();
    if (_state.mapInitError != null) {
      // 지도 없이 목록으로만 동작. 거리 정렬을 위해 위치만 요청.
      _listMode = true;
      _state.locate();
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _search.dispose();
    super.dispose();
  }

  String _signature() =>
      '${_state.query}|${_state.categories.map((c) => c.key).join(',')}|${_state.openNowOnly}|${_state.dataset?.dataVersion}|${_state.allStores.length}';

  void _onStateChanged() {
    final sig = _signature();
    if (sig != _filterSignature) {
      _filterSignature = sig;
      if (_selected != null && _state.storeById(_selected!.id) == null) setState(() => _selected = null);
      _renderMarkers();
    }
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _map = controller;
    _meLayer = controller.labelLayer;
    await hideBaseMapPois(controller);
    await _renderMarkers();
    unawaited(_locateMe(move: true));
  }

  Future<void> _locateMe({bool move = true}) async {
    final p = await _state.locate();
    if (!mounted) return;
    if (p == null) {
      if (_state.locationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_state.locationError!)));
      }
      return;
    }
    final me = _meLayer;
    if (me != null) {
      final mePoi = _mePoi;
      if (mePoi == null) {
        _mePoi = await me.addPoi(LatLng(p.lat, p.lng), style: await _styles.me());
      } else {
        await mePoi.move(LatLng(p.lat, p.lng));
      }
    }
    if (move) {
      await _map?.moveCamera(CameraUpdate.newCenterPosition(LatLng(p.lat, p.lng), zoomLevel: 15),
          animation: const CameraAnimation(400));
    }
  }

  /// 현재 화면 영역의 마커를 다시 그린다. 진행 중이면 끝난 뒤 한 번 더 그린다.
  Future<void> _renderMarkers() async {
    final map = _map;
    if (map == null) return;
    if (_rendering) {
      _renderAgain = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _renderAgain = false;
        await _renderOnce(map);
      } while (_renderAgain && mounted);
    } catch (e) {
      if (mounted) setState(() => _mapError = '지도 표시 오류: $e');
    } finally {
      _rendering = false;
    }
  }

  Future<void> _renderOnce(KakaoMapController map) async {
    final seq = ++_renderSeq;
    final box = _mapKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // fromScreenPoint는 물리 픽셀 좌표를 받는다(플러그인 getBounds는 논리 크기를 넘겨 화면 일부만 계산됨).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = (box.size.width * dpr).round();
    final h = (box.size.height * dpr).round();
    final camera = await map.getCameraPosition();
    final corners = await Future.wait([map.fromScreenPoint(0, 0), map.fromScreenPoint(w, h)]);
    final nw = corners[0];
    final se = corners[1];
    if (nw == null || se == null) return;
    _center = GeoPoint(camera.position.latitude, camera.position.longitude);
    _zoom = camera.zoomLevel;

    final groups = clusterStores(
      _state.filteredStores(),
      Bounds(
        south: se.latitude < nw.latitude ? se.latitude : nw.latitude,
        north: se.latitude < nw.latitude ? nw.latitude : se.latitude,
        west: nw.longitude < se.longitude ? nw.longitude : se.longitude,
        east: nw.longitude < se.longitude ? se.longitude : nw.longitude,
      ),
      zoomLevel: _zoom,
    );
    final showNames = _zoom >= 16;

    // 기본 레이어에 새 마커를 모두 올린 뒤 이전 마커를 지운다(깜빡임 최소화).
    final layer = map.labelLayer;
    final added = <Poi>[];
    for (final g in groups) {
      if (seq != _renderSeq) break;
      if (g.isSingle) {
        final s = g.stores.first;
        final selected = s.id == _selected?.id;
        added.add(await layer.addPoi(
          LatLng(s.lat, s.lng),
          style: await _styles.store(s.category, selected: selected, showName: showNames),
          text: showNames || selected ? s.name : null,
          rank: selected ? 1000 : 0,
          onClick: () => _select(s),
        ));
      } else {
        added.add(await layer.addPoi(
          LatLng(g.lat, g.lng),
          style: await _styles.cluster(g.stores.length, sameSpot: g.colocated),
          rank: g.stores.length,
          onClick: () => _onGroupTap(g),
        ));
      }
    }
    final old = _storePois;
    _storePois = added;
    await Future.wait(old.map(layer.removePoi));
    if (mounted) setState(() {});
  }

  void _select(Store s) {
    setState(() => _selected = s);
    _renderMarkers();
  }

  /// 같은 건물 가게 묶음은 목록으로 고르고, 넓은 묶음은 확대한다.
  Future<void> _onGroupTap(MarkerGroup g) async {
    if (!g.colocated) {
      await _map?.moveCamera(
        CameraUpdate.newCenterPosition(LatLng(g.lat, g.lng), zoomLevel: _zoom + 2),
        animation: const CameraAnimation(300),
      );
      return;
    }
    final picked = await showModalBottomSheet<Store>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('이 건물의 가게 ${g.stores.length}곳',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final s in g.stores) StoreTile(s, origin: _state.userLocation, onTap: () => Navigator.pop(ctx, s)),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) _select(picked);
  }

  Future<void> _focusStore(Store s) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _listMode = false;
      _selected = s;
    });
    await _map?.moveCamera(CameraUpdate.newCenterPosition(LatLng(s.lat, s.lng), zoomLevel: 17),
        animation: const CameraAnimation(400));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final top = MediaQuery.paddingOf(context).top;
    final mapAvailable = state.mapInitError == null;
    final showCard = _selected != null && !_listMode;
    return Scaffold(
      body: Stack(children: [
        if (mapAvailable)
          Positioned.fill(
            child: KakaoMap(
              key: _mapKey,
              option: KakaoMapOption(position: LatLng(daejeonCenter.lat, daejeonCenter.lng), zoomLevel: 13),
              onMapReady: _onMapReady,
              onMapError: (e) => setState(() => _mapError = '지도를 불러오지 못했어요: $e'),
              onCameraMoveEnd: (_, _) => _renderMarkers(),
              onMapClick: (_, _) {
                if (_selected != null) {
                  setState(() => _selected = null);
                  _renderMarkers();
                }
              },
            ),
          ),
        if (_listMode)
          Positioned.fill(
            child: Container(
              color: Palette.cream,
              padding: EdgeInsets.only(top: top + 124),
              child: _StoreList(
                near: mapAvailable ? _center : (state.userLocation ?? daejeonCenter),
                onTap: mapAvailable ? _focusStore : (s) => openStoreDetail(context, s),
                notice: state.mapInitError,
                originLabel: mapAvailable ? '지도 중심에서 가까운 순' : '현재 위치(또는 대전 중심)에서 가까운 순',
              ),
            ),
          ),
        // 상단: 검색 + 필터
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, top + 10, 0, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.cream.withValues(alpha: _listMode ? 1 : 0.85), Palette.cream.withValues(alpha: 0)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _SearchBar(
                  controller: _search,
                  onChanged: state.setQuery,
                  onSubmitted: (_) => setState(() => _listMode = true),
                ),
              ),
              const SizedBox(height: 10),
              _FilterChips(state: state),
            ]),
          ),
        ),
        if (_mapError != null)
          Positioned(
            left: 16,
            right: 16,
            top: top + 130,
            child: Material(
              color: const Color(0xFFFFE9E4),
              borderRadius: BorderRadius.circular(12),
              child: Padding(padding: const EdgeInsets.all(12), child: Text(_mapError!)),
            ),
          ),
        // 하단: 목록/지도 전환 + 현재 위치 + 선택 카드 (높이를 고정하지 않고 위로 쌓는다)
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Spacer(),
              if (mapAvailable)
                _FloatingPill(
                  icon: _listMode ? Icons.map_rounded : Icons.format_list_bulleted_rounded,
                  label: _listMode ? '지도 보기' : '목록 보기',
                  onTap: () => setState(() => _listMode = !_listMode),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _listMode
                      ? const SizedBox.shrink()
                      : _RoundButton(icon: Icons.my_location_rounded, tooltip: '현재 위치', onTap: () => _locateMe()),
                ),
              ),
            ]),
            if (showCard) ...[
              const SizedBox(height: 12),
              _SelectedCard(store: _selected!),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged, required this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Material(
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        child: SizedBox(
          height: 52,
          child: Row(children: [
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Palette.cocoa, shape: BoxShape.circle),
              child: const Icon(Icons.bakery_dining_rounded, color: Palette.butter, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: '빵집·디저트·메뉴 검색',
                  hintStyle: TextStyle(color: Palette.muted, fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, v, _) => v.text.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.search_rounded, color: Palette.cocoa),
                    )
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: Palette.muted),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
          ]),
        ),
      );
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            _Chip(
              icon: Icons.schedule_rounded,
              label: '영업 중',
              color: const Color(0xFF3E8E5A),
              selected: state.openNowOnly,
              onTap: () => state.setOpenNowOnly(!state.openNowOnly),
            ),
            for (final c in StoreCategory.values)
              _Chip(
                icon: categoryIcon(c),
                label: c.shortLabel,
                color: categoryColor(c),
                selected: state.categories.contains(c),
                onTap: () => state.toggleCategory(c),
              ),
          ],
        ),
      );
}

/// 선택 전: 흰 바탕 + 업종 색 아이콘, 선택 후: 업종 색 바탕 + 흰 글자.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? color : Colors.white,
          shape: const StadiumBorder(),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: selected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Palette.espresso)),
              ]),
            ),
          ),
        ),
      );
}

class _StoreList extends StatelessWidget {
  const _StoreList({required this.near, required this.onTap, required this.originLabel, this.notice});
  final GeoPoint near;
  final ValueChanged<Store> onTap;
  final String originLabel;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stores = state.filteredStores(near: near);
    if (stores.isEmpty) {
      return const EmptyState(icon: Icons.search_off_rounded, title: '조건에 맞는 가게가 없어요', message: '검색어나 필터를 바꿔보세요.');
    }
    return Column(children: [
      if (notice != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFE9E4), borderRadius: BorderRadius.circular(12)),
          child: Text(notice!, style: const TextStyle(fontSize: 13)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(children: [
          Text('${stores.length}곳', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text('· $originLabel', style: const TextStyle(color: Palette.muted)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: stores.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: Palette.dough),
          itemBuilder: (_, i) => StoreTile(
            stores[i],
            origin: near,
            onTap: () => onTap(stores[i]),
            trailing: IconButton(
              tooltip: '상세 보기',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => openStoreDetail(context, stores[i]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fav = state.isFavorite(store.id);
    final status = state.statusOf(store);
    final here = state.userLocation;
    final distance = here == null ? null : formatDistance(distanceMeters(here, GeoPoint(store.lat, store.lng)));
    final signature = store.products.take(2).map((p) => p.name).join(' · ');
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openStoreDetail(context, store),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StoreThumb(store, size: 60, radius: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 6),
                  Row(children: [
                    CategoryPill(store.category),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: statusColor(status.state), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    [?distance, signature.isEmpty ? store.address : signature].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Palette.muted),
                  ),
                ]),
              ),
              IconButton(
                tooltip: fav ? '찜 해제' : '찜하기',
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: fav ? Palette.berry : Palette.muted),
                onPressed: () => state.toggleFavorite(store.id),
              ),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(children: [
                _CardAction(
                  icon: Icons.navigation_rounded,
                  label: '네이버',
                  onTap: () => openDirections(MapApp.naver, store, from: here, fromName: '현재 위치'),
                ),
                const SizedBox(width: 8),
                _CardAction(
                  icon: Icons.directions_walk_rounded,
                  label: '카카오',
                  onTap: () => openDirections(MapApp.kakao, store, from: here),
                ),
                const SizedBox(width: 8),
                _CardAction(
                  icon: Icons.add_location_alt_rounded,
                  label: '코스 담기',
                  primary: true,
                  onTap: () => showAddToCourseSheet(context, store),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 카드 하단 동작 버튼. 글자 크기를 키워도 줄바꿈 없이 줄어든다.
class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : Palette.cocoa;
    return Expanded(
      child: Material(
        color: primary ? Palette.cocoa : Palette.cream,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Text(label, maxLines: 1, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Palette.espresso,
        shape: const StadiumBorder(),
        elevation: 4,
        shadowColor: Colors.black38,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: IconButton(tooltip: tooltip, icon: Icon(icon, color: Palette.cocoa, size: 22), onPressed: onTap),
      );
}
