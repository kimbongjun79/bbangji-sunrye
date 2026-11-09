import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store.dart';
import '../state/app_state.dart';
import 'theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final d = state.dataset;
    final counts = {for (final c in StoreCategory.values) c: state.allStores.where((s) => s.category == c).length};
    final syncText = switch (state.syncState) {
      DataSyncState.checking => '새 데이터 확인 중…',
      DataSyncState.updated => '새 데이터를 받았어요',
      DataSyncState.failed => '새 데이터 확인 실패 (저장된 데이터 사용 중)',
      DataSyncState.idle => '최신 데이터예요',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('빵지순례')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('데이터', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('데이터 버전 ${d?.dataVersion ?? '-'}'),
              Text('등록 가게 ${state.allStores.length}곳 · 상세 정보 검수 ${d?.curatedCount ?? 0}곳'),
              for (final e in counts.entries) Text('  ${e.key.label} ${e.value}곳'),
              const SizedBox(height: 8),
              Text(syncText, style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.syncState == DataSyncState.checking ? null : state.syncRemote,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('지금 확인'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('알아두세요', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(d?.coverageNote ?? ''),
              const SizedBox(height: 6),
              const Text('· 가게 목록은 지방행정 인허가 데이터(공공데이터포털)의 영업 중 업소를 기준으로 매달 갱신돼요. 신규·폐업 반영이 늦을 수 있어요.'),
              const Text('· 영업시간·상품·가격은 출처와 확인일이 있는 가게만 표시하고, 모르는 정보는 ‘미확인’으로 보여줘요.'),
              const Text('· ‘영업 중’은 등록된 영업시간 기준이에요. 임시휴무는 가게 공지를 확인하세요.'),
              const Text('· 코스 순서 추천은 직선거리 기준이에요.'),
              const Text('· 찜과 코스는 이 휴대폰에만 저장돼요. 앱을 지우면 사라져요.'),
            ]),
          ),
        ),
      ]),
    );
  }
}
