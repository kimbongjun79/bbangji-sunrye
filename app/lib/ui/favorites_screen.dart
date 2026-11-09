import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stores = state.favoriteStores..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('찜한 가게')),
      body: stores.isEmpty
          ? const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: '아직 찜한 가게가 없어요',
              message: '가게 상세 화면의 하트를 눌러 담아보세요.\n찜 목록은 이 휴대폰에만 저장돼요.',
            )
          : ListView.separated(
              itemCount: stores.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: Palette.dough),
              itemBuilder: (_, i) => StoreTile(
                stores[i],
                origin: state.userLocation,
                trailing: IconButton(
                  tooltip: '찜 해제',
                  icon: const Icon(Icons.favorite_rounded, color: Palette.berry),
                  onPressed: () => state.toggleFavorite(stores[i].id),
                ),
              ),
            ),
    );
  }
}
