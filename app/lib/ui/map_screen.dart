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
  LabelController? _storeLayer;
  LabelController? _meLayer;
  int _layerSeq = 0;
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
    _meLayer = await controller.addLabelLayer('me', zOrder: 20000);
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
      await me.hideAllPoi();
      await me.addPoi(LatLng(p.lat, p.lng), style: await _styles.me());
    }
    // 대전 밖이면 지도를 옮기지 않는다.
    final inDaejeon = distanceMeters(p, daejeonCenter) < 30000;
    if (move && inDaejeon) {
      await _map?.moveCamera(CameraUpdate.newCenterPosition(LatLng(p.lat, p.lng), zoomLevel: 15),
          animation: const CameraAnimation(400));
    } else if (move && !inDaejeon && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('현재 위치가 대전 밖이라 대전 중심을 보여드려요')));
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
    final ctx = _mapKey.currentContext;
    if (ctx == null) return;
    final boundsFuture = map.getBounds(ctx);
    final camera = await map.getCameraPosition();
    final bounds = await boundsFuture;
    if (bounds == null) return;
    _center = GeoPoint(camera.position.latitude, camera.position.longitude);
    _zoom = camera.zoomLevel;

    final groups = clusterStores(
      _state.filteredStores(),
      Bounds(south: bounds.sw.latitude, west: bounds.sw.longitude, north: bounds.ne.latitude, east: bounds.ne.longitude),
      zoomLevel: _zoom,
    );
    final showNames = _zoom >= 16;

    final layer = await map.addLabelLayer('stores-${++_layerSeq}', competitionType: CompetitionType.none, zOrder: 10000);
    for (final g in groups) {
      if (seq != _renderSeq) break;
      if (g.isSingle) {
        final s = g.stores.first;
        final selected = s.id == _selected?.id;
        await layer.addPoi(
          LatLng(s.lat, s.lng),
          style: await _styles.store(s.category, selected: selected, showName: showNames),
          text: showNames || selected ? s.name : null,
          rank: selected ? 1000 : 0,
          onClick: () => _select(s),
        );
      } else {
        await layer.addPoi(
          LatLng(g.lat, g.lng),
          style: await _styles.cluster(g.stores.length),
          rank: g.stores.length,
          onClick: () => _map?.moveCamera(
            CameraUpdate.newCenterPosition(LatLng(g.lat, g.lng), zoomLevel: _zoom + 2),
            animation: const CameraAnimation(300),
          ),
        );
      }
    }
    final old = _storeLayer;
    _storeLayer = layer;
    if (old != null) await map.removeLabelLayer(old);
    if (mounted) setState(() {});
  }

  void _select(Store s) {
    setState(() => _selected = s);
    _renderMarkers();
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
    return Scaffold(
      body: Stack(children: [
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
              padding: EdgeInsets.only(top: top + 118),
              child: _StoreList(near: _center, onTap: _focusStore),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: top + 8,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SearchBar(
              controller: _search,
              onChanged: state.setQuery,
              onSubmitted: (_) => setState(() => _listMode = true),
            ),
            const SizedBox(height: 8),
            _FilterChips(state: state),
          ]),
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
        if (!_listMode)
          Positioned(
            right: 12,
            bottom: (_selected == null ? 16 : 176),
            child: Column(children: [
              _RoundButton(icon: Icons.my_location_rounded, tooltip: '현재 위치', onTap: () => _locateMe()),
            ]),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: _selected == null || _listMode ? 16 : 176,
          child: Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Palette.espresso,
                elevation: 3,
                shadowColor: Colors.black26,
              ),
              onPressed: () => setState(() => _listMode = !_listMode),
              icon: Icon(_listMode ? Icons.map_rounded : Icons.format_list_bulleted_rounded),
              label: Text(_listMode ? '지도 보기' : '목록 보기'),
            ),
          ),
        ),
        if (_selected != null && !_listMode)
          Positioned(left: 12, right: 12, bottom: 12, child: _SelectedCard(store: _selected!)),
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
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '가게·상품 검색 (소금빵, 성심당, 휘낭시에)',
            prefixIcon: const Icon(Icons.search_rounded, color: Palette.cocoa),
            suffixIcon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, v, _) => v.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          FilterChip(
            avatar: const Icon(Icons.schedule_rounded, size: 16),
            label: const Text('영업 중'),
            selected: state.openNowOnly,
            showCheckmark: false,
            onSelected: state.setOpenNowOnly,
          ),
          const SizedBox(width: 6),
          for (final c in StoreCategory.values) ...[
            FilterChip(
              avatar: Icon(categoryIcon(c), size: 16, color: categoryColor(c)),
              label: Text(c.label),
              selected: state.categories.contains(c),
              showCheckmark: false,
              onSelected: (_) => state.toggleCategory(c),
            ),
            const SizedBox(width: 6),
          ],
        ]),
      );
}

class _StoreList extends StatelessWidget {
  const _StoreList({required this.near, required this.onTap});
  final GeoPoint near;
  final ValueChanged<Store> onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stores = state.filteredStores(near: near);
    if (stores.isEmpty) {
      return const EmptyState(icon: Icons.search_off_rounded, title: '조건에 맞는 가게가 없어요', message: '검색어나 필터를 바꿔보세요.');
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(children: [
          Text('${stores.length}곳', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          const Text('· 지도 중심에서 가까운 순', style: TextStyle(color: Palette.muted)),
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
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openStoreDetail(context, store),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            StoreTile(
              store,
              origin: state.userLocation,
              onTap: () => openStoreDetail(context, store),
              trailing: IconButton(
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: fav ? Palette.berry : Palette.muted),
                onPressed: () => state.toggleFavorite(store.id),
              ),
            ),
            Row(children: [
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openDirections(MapApp.naver, store, from: state.userLocation, fromName: '현재 위치'),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('네이버'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openDirections(MapApp.kakao, store, from: state.userLocation),
                  icon: const Icon(Icons.directions_walk_rounded, size: 18),
                  label: const Text('카카오'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showAddToCourseSheet(context, store),
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text('코스'),
                ),
              ),
              const SizedBox(width: 12),
            ]),
          ]),
        ),
      ),
    );
  }
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
        elevation: 3,
        shadowColor: Colors.black26,
        child: IconButton(tooltip: tooltip, icon: Icon(icon, color: Palette.cocoa), onPressed: onTap),
      );
}
