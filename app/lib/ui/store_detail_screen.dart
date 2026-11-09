import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/open_status.dart';
import '../models/store.dart';
import '../services/external_links.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

void openStoreDetail(BuildContext context, Store store) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StoreDetailScreen(store: store)));
}

class StoreDetailScreen extends StatelessWidget {
  const StoreDetailScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fav = state.isFavorite(store.id);
    final status = state.statusOf(store);
    final todayIndex = state.now().weekday - 1;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          backgroundColor: Palette.cream,
          actions: [
            IconButton(
              tooltip: fav ? '찜 해제' : '찜하기',
              icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? Palette.berry : Palette.espresso),
              onPressed: () => state.toggleFavorite(store.id),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(background: _Hero(store: store)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CategoryPill(store.category),
                if (store.franchise == true) ...[
                  const SizedBox(width: 6),
                  const Text('프랜차이즈', style: TextStyle(color: Palette.muted, fontSize: 12)),
                ],
              ]),
              const SizedBox(height: 8),
              Text(store.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(status.label,
                  style: TextStyle(color: statusColor(status.state), fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              _ActionRow(store: store),
            ]),
          ),
        ),
        _section('영업시간', [
          if (store.hours == null)
            const _Unknown('영업시간 미확인')
          else
            for (var i = 0; i < 7; i++)
              _HoursRow(
                day: weekdayLabels[i],
                text: store.hours!.isKnown(i) ? formatDayHours(store.hours!.of(i)) : '미확인',
                today: i == todayIndex,
              ),
          if (store.holidayNote != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.event_busy_rounded, size: 18, color: Palette.berry),
              const SizedBox(width: 6),
              Expanded(child: Text(store.holidayNote!)),
            ]),
          ],
          const SizedBox(height: 8),
          const Text('등록된 정보 기준이며 임시휴무·조기마감은 반영되지 않을 수 있어요.',
              style: TextStyle(color: Palette.muted, fontSize: 12)),
        ]),
        _section('대표 상품', [
          if (store.products.isEmpty)
            const _Unknown('대표 상품 미확인')
          else
            for (final p in store.products)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.circle, size: 6, color: Palette.crust),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (p.note != null) Text(p.note!, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    ]),
                  ),
                  Text(p.price == null ? '가격 미확인' : '${_won(p.price!)}원',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: p.price == null ? Palette.muted : Palette.espresso)),
                ]),
              ),
        ]),
        _section('정보', [
          _InfoRow(icon: Icons.place_rounded, text: store.address),
          _InfoRow(
            icon: Icons.call_rounded,
            text: store.phone ?? '전화번호 미확인',
            onTap: store.phone == null ? null : () => callPhone(store.phone!),
          ),
          if (store.instagram != null)
            _InfoRow(
              icon: Icons.camera_alt_rounded,
              text: _instagramHandle(store.instagram!),
              onTap: () => openUrl(store.instagram!),
            ),
          if (store.website != null)
            _InfoRow(icon: Icons.language_rounded, text: store.website!, onTap: () => openUrl(store.website!)),
        ]),
        _section('출처·확인일', [
          Text(
            store.verifiedAt == null ? '상세 정보 미검수' : '상세 정보 확인일 ${store.verifiedAt}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (store.licenseCheckedAt != null)
            Text('영업 신고 정보 확인일 ${store.licenseCheckedAt} (지방행정 인허가 데이터)',
                style: const TextStyle(color: Palette.muted, fontSize: 13)),
          for (final s in store.sources)
            InkWell(
              onTap: () => openUrl(s.url),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('· ${s.title ?? s.url}${s.checkedAt == null ? '' : ' (${s.checkedAt})'}',
                    style: const TextStyle(color: Palette.cocoa, decoration: TextDecoration.underline, fontSize: 13)),
              ),
            ),
        ]),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }

  static String _won(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  static String _instagramHandle(String url) {
    final m = RegExp(r'instagram\.com/([^/?#]+)').firstMatch(url);
    return m == null ? url : '@${m.group(1)}';
  }

  Widget _section(String title, List<Widget> children) => SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    if (store.photos.isNotEmpty) {
      return Stack(fit: StackFit.expand, children: [
        Image.network(store.photos.first.url, fit: BoxFit.cover, errorBuilder: (_, _, _) => _illustration()),
        if (store.photos.first.credit != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: Text('사진: ${store.photos.first.credit}',
                style: const TextStyle(color: Colors.white, fontSize: 11, shadows: [Shadow(blurRadius: 4)])),
          ),
      ]);
    }
    return _illustration();
  }

  Widget _illustration() {
    final color = categoryColor(store.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.35), Palette.dough, Palette.cream],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(categoryIcon(store.category), size: 96, color: color.withValues(alpha: 0.8))),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    Widget action(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Icon(icon, color: onTap == null ? Palette.muted.withValues(alpha: 0.4) : Palette.cocoa),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onTap == null ? Palette.muted.withValues(alpha: 0.6) : Palette.espresso)),
              ]),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        action(Icons.call_rounded, '전화', store.phone == null ? null : () => callPhone(store.phone!)),
        action(Icons.navigation_rounded, '네이버 길찾기',
            () => openDirections(MapApp.naver, store, from: state.userLocation, fromName: '현재 위치')),
        action(Icons.directions_walk_rounded, '카카오 길찾기',
            () => openDirections(MapApp.kakao, store, from: state.userLocation)),
        action(Icons.playlist_add_rounded, '코스에 담기', () => showAddToCourseSheet(context, store)),
      ]),
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.day, required this.text, required this.today});
  final String day;
  final String text;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: today ? FontWeight.w800 : FontWeight.w500, color: Palette.espresso);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 44, child: Text(today ? '$day(오늘)' : day, style: style)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: style)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(icon, size: 20, color: Palette.crust),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: onTap == null ? Palette.espresso : Palette.cocoa,
                      fontWeight: onTap == null ? FontWeight.w500 : FontWeight.w700)),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Palette.muted),
          ]),
        ),
      );
}

class _Unknown extends StatelessWidget {
  const _Unknown(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.help_outline_rounded, size: 18, color: Palette.muted),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Palette.muted)),
      ]);
}
