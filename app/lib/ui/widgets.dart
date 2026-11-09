import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store.dart';
import '../services/geo.dart';
import '../state/app_state.dart';
import 'store_detail_screen.dart';
import 'theme.dart';

class StatusText extends StatelessWidget {
  const StatusText(this.store, {super.key});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AppState>().statusOf(store);
    return Text(
      status.label,
      style: TextStyle(color: statusColor(status.state), fontWeight: FontWeight.w700, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class CategoryPill extends StatelessWidget {
  const CategoryPill(this.category, {super.key});
  final StoreCategory category;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(categoryIcon(category), size: 14, color: color),
        const SizedBox(width: 4),
        Text(category.label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 사진 권한이 없는 가게는 업종 일러스트로 대체.
class StoreThumb extends StatelessWidget {
  const StoreThumb(this.store, {super.key, this.size = 64, this.radius = 14});
  final Store store;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(store.category);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), Palette.dough],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(categoryIcon(store.category), color: color, size: size * 0.5),
    );
    if (store.photos.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(store.photos.first.url,
          width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

class StoreTile extends StatelessWidget {
  const StoreTile(this.store, {super.key, this.origin, this.trailing, this.onTap});
  final Store store;
  final GeoPoint? origin;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final signature = store.products.take(2).map((p) => p.name).join(' · ');
    final distance = origin == null ? null : formatDistance(distanceMeters(origin!, GeoPoint(store.lat, store.lng)));
    return InkWell(
      onTap: onTap ?? () => openStoreDetail(context, store),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          StoreThumb(store),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(store.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                CategoryPill(store.category),
              ]),
              const SizedBox(height: 3),
              StatusText(store),
              const SizedBox(height: 2),
              Text(
                [?distance, signature.isEmpty ? store.district : signature].join(' · '),
                style: const TextStyle(color: Palette.muted, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Palette.crust),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: const TextStyle(color: Palette.muted), textAlign: TextAlign.center),
            ],
          ]),
        ),
      );
}

/// 코스 선택 후 가게 담기.
Future<void> showAddToCourseSheet(BuildContext context, Store store) async {
  final state = context.read<AppState>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('코스에 담기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        for (final c in state.courses)
          ListTile(
            leading: const Icon(Icons.route_rounded, color: Palette.crust),
            title: Text(c.name),
            subtitle: Text('${c.storeIds.length}곳'),
            trailing: c.storeIds.contains(store.id) ? const Icon(Icons.check_rounded, color: Palette.mint) : null,
            onTap: () {
              state.addToCourse(c, store.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('‘${c.name}’에 담았어요')));
            },
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded, color: Palette.cocoa),
          title: const Text('새 코스 만들기'),
          onTap: () async {
            final name = await promptText(ctx, title: '새 코스 이름', initial: '빵지순례 ${state.courses.length + 1}');
            if (name == null) return;
            final c = state.createCourse(name);
            state.addToCourse(c, store.id);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('‘$name’에 담았어요')));
            }
          },
        ),
      ]),
    ),
  );
}

Future<String?> promptText(BuildContext context, {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            Navigator.pop(ctx, v.isEmpty ? null : v);
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
