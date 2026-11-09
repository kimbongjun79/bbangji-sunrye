import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/store.dart';

/// 승인(병합)된 배포 데이터. 갱신 PR이 main에 병합되면 이 주소의 내용이 바뀐다.
const remoteDataUrl = 'https://raw.githubusercontent.com/kimbongjun79/bbangji-sunrye/main/data/stores.json';
const _bundledAsset = 'assets/data/stores.json';
const _cacheFile = 'stores_cache.json';

class StoreRepository {
  StoreRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<File> _cache() async => File('${(await getApplicationSupportDirectory()).path}/$_cacheFile');

  /// 기기 캐시가 있으면 캐시, 없으면 앱에 포함된 데이터.
  Future<StoreDataset> loadLocal() async {
    final bundled = StoreDataset.fromJson(jsonDecode(await rootBundle.loadString(_bundledAsset)) as Map<String, dynamic>);
    try {
      final file = await _cache();
      if (await file.exists()) {
        final cached = StoreDataset.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
        // 앱 업데이트로 더 새 데이터가 포함된 경우 포함본 사용.
        if (cached.dataVersion.compareTo(bundled.dataVersion) >= 0) return cached;
      }
    } catch (_) {
      // 손상된 캐시는 무시하고 포함 데이터 사용.
    }
    return bundled;
  }

  /// 원격 데이터가 [current]와 다르면 내려받아 캐시하고 반환. 변경 없거나 실패하면 null.
  Future<StoreDataset?> fetchRemote(StoreDataset current) async {
    final res = await _client.get(Uri.parse(remoteDataUrl)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw HttpException('데이터 서버 응답 ${res.statusCode}');
    final body = utf8.decode(res.bodyBytes);
    final remote = StoreDataset.fromJson(jsonDecode(body) as Map<String, dynamic>);
    if (remote.dataVersion == current.dataVersion && remote.generatedAt == current.generatedAt) return null;
    if (remote.stores.isEmpty) return null;
    await (await _cache()).writeAsString(body, flush: true);
    return remote;
  }
}
