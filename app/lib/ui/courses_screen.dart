import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store.dart';
import '../services/external_links.dart';
import '../services/geo.dart';
import '../state/app_state.dart';
import 'course_map.dart';
import 'theme.dart';
import 'widgets.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('빵지순례 코스')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Palette.cocoa,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 코스'),
        onPressed: () async {
          final name = await promptText(context, title: '새 코스 이름', initial: '빵지순례 ${state.courses.length + 1}');
          if (name == null || !context.mounted) return;
          final c = state.createCourse(name);
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CourseDetailScreen(course: c)));
        },
      ),
      body: state.courses.isEmpty
          ? const EmptyState(
              icon: Icons.route_rounded,
              title: '코스를 만들어 보세요',
              message: '가게 상세에서 ‘코스에 담기’를 누르거나\n새 코스를 만들어 방문할 가게를 모아요.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final c in state.courses)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: const CircleAvatar(
                        backgroundColor: Palette.dough,
                        child: Icon(Icons.route_rounded, color: Palette.cocoa),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        state.courseStores(c).isEmpty
                            ? '담긴 가게 없음'
                            : state.courseStores(c).map((s) => s.name).join(' → '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => CourseDetailScreen(course: c))),
                    ),
                  ),
              ],
            ),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stores = state.courseStores(course);
    final start = state.userLocation;
    final total = stores.isEmpty
        ? 0.0
        : routeLength(start ?? GeoPoint(stores.first.lat, stores.first.lng), [for (final s in stores) GeoPoint(s.lat, s.lng)]);

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await promptText(context, title: '코스 이름 변경', initial: course.name);
                if (name != null) state.renameCourse(course, name);
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('코스를 삭제할까요?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  state.deleteCourse(course);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('이름 변경')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
      body: stores.isEmpty
          ? const EmptyState(
              icon: Icons.bakery_dining_rounded,
              title: '아직 담긴 가게가 없어요',
              message: '지도나 검색에서 가게를 고른 뒤\n‘코스에 담기’를 눌러주세요.',
            )
          : Column(children: [
              if (state.mapInitError == null) SizedBox(height: 220, child: CourseMap(stores: stores, start: start)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${stores.length}곳 · 직선거리 합계 ${formatDistance(total)}'
                      '${start == null ? ' (첫 가게 출발)' : ' (현재 위치 출발)'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: stores.length < 2 ? null : () => _optimize(context, state, stores),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('순서 추천'),
                  ),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('길게 눌러 끌면 순서를 바꿀 수 있어요.', style: TextStyle(color: Palette.muted, fontSize: 12)),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: stores.length,
                  onReorderItem: (a, b) {
                    final ids = [for (final s in stores) s.id];
                    ids.insert(b, ids.removeAt(a));
                    state.setCourseOrder(course, ids);
                  },
                  itemBuilder: (ctx, i) {
                    final s = stores[i];
                    final prev = i == 0 ? start : GeoPoint(stores[i - 1].lat, stores[i - 1].lng);
                    return Container(
                      key: ValueKey(s.id),
                      color: Palette.cream,
                      child: Row(children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Palette.cocoa,
                            child: Text('${i + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        Expanded(
                          child: StoreTile(
                            s,
                            origin: prev,
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (v) {
                                final fromName = i == 0 ? '현재 위치' : stores[i - 1].name;
                                switch (v) {
                                  case 'naver':
                                    openDirections(MapApp.naver, s, from: prev, fromName: fromName);
                                  case 'kakao':
                                    openDirections(MapApp.kakao, s, from: prev);
                                  case 'remove':
                                    state.removeFromCourse(course, s.id);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'naver', child: Text(i == 0 ? '여기까지 네이버 길찾기' : '이전 가게에서 네이버 길찾기')),
                                PopupMenuItem(
                                    value: 'kakao', child: Text(i == 0 ? '여기까지 카카오 길찾기' : '이전 가게에서 카카오 길찾기')),
                                const PopupMenuItem(value: 'remove', child: Text('코스에서 빼기')),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ]),
    );
  }

  Future<void> _optimize(BuildContext context, AppState state, List<Store> stores) async {
    var fixLast = false;
    var useLocation = state.userLocation != null;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('방문 순서 추천', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                '가게 사이의 직선거리 합이 가장 짧아지는 순서를 계산해요. 도로·교통·영업시간은 반영하지 않으니 실제 이동은 길찾기로 확인하세요.',
                style: TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('현재 위치에서 출발'),
                subtitle: Text(state.userLocation == null ? '위치 정보가 없어 첫 가게에서 출발해요' : '끄면 지금 첫 번째 가게에서 출발'),
                value: useLocation,
                onChanged: state.userLocation == null ? null : (v) => setSheet(() => useLocation = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('마지막 가게 고정'),
                subtitle: Text('‘${stores.last.name}’을(를) 마지막에 방문'),
                value: fixLast,
                onChanged: (v) => setSheet(() => fixLast = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추천 순서 계산')),
              ),
            ]),
          ),
        ),
      ),
    );
    if (apply != true || !context.mounted) return;

    final points = [for (final s in stores) GeoPoint(s.lat, s.lng)];
    final List<int> order;
    final GeoPoint start;
    if (useLocation) {
      start = state.userLocation!;
      order = optimizeVisitOrder(start, points, fixLastIndex: fixLast ? points.length - 1 : null);
    } else {
      // 첫 가게를 출발점으로 고정하고 나머지를 정렬.
      start = points.first;
      final rest = points.sublist(1);
      order = [0, ...optimizeVisitOrder(start, rest, fixLastIndex: fixLast ? rest.length - 1 : null).map((i) => i + 1)];
    }
    final before = routeLength(start, points);
    final after = routeLength(start, [for (final i in order) points[i]]);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('추천 순서'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var k = 0; k < order.length; k++) Text('${k + 1}. ${stores[order[k]].name}'),
          const SizedBox(height: 12),
          Text('직선거리 ${formatDistance(before)} → ${formatDistance(after)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그대로 두기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('적용')),
        ],
      ),
    );
    if (ok == true) state.setCourseOrder(course, [for (final i in order) stores[i].id]);
  }
}
