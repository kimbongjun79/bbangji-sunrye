import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/store_repository.dart';
import '../models/open_status.dart';
import '../models/store.dart';
import '../services/geo.dart';

/// 대전시청 부근. 위치 권한이 없을 때 기준점.
const daejeonCenter = GeoPoint(36.3504, 127.3845);

class Course {
  Course({required this.id, required this.name, required this.storeIds});
  final String id;
  String name;
  final List<String> storeIds;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'storeIds': storeIds};
  factory Course.fromJson(Map<String, dynamic> j) =>
      Course(id: j['id'] as String, name: j['name'] as String, storeIds: [...(j['storeIds'] as List).cast<String>()]);
}

enum DataSyncState { idle, checking, updated, failed }

class AppState extends ChangeNotifier {
  AppState(this._repo, this._prefs, {DateTime Function()? clock, this.mapInitError}) : _clock = clock ?? nowKst;

  /// 가게 영업시간은 한국 시간 기준. 기기 시간대와 무관하게 KST 벽시계 시각을 쓴다.
  static DateTime nowKst() {
    final k = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(k.year, k.month, k.day, k.hour, k.minute, k.second);
  }

  /// 지도 SDK를 쓸 수 없는 이유. null이면 지도 사용 가능.
  final String? mapInitError;

  final StoreRepository _repo;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  StoreDataset? dataset;
  Map<String, Store> _byId = {};
  DataSyncState syncState = DataSyncState.idle;

  String query = '';
  final Set<StoreCategory> categories = {...StoreCategory.values};
  bool openNowOnly = false;

  final Set<String> favorites = {};
  final List<Course> courses = [];

  GeoPoint? userLocation;
  String? locationError;

  DateTime now() => _clock();

  Future<void> init() async {
    favorites.addAll(_prefs.getStringList('favorites') ?? const []);
    final raw = _prefs.getString('courses');
    if (raw != null) {
      courses.addAll([for (final c in jsonDecode(raw) as List) Course.fromJson(c as Map<String, dynamic>)]);
    }
    _setDataset(await _repo.loadLocal());
    notifyListeners();
  }

  void _setDataset(StoreDataset d) {
    dataset = d;
    _byId = {for (final s in d.stores) s.id: s};
  }

  Future<void> syncRemote() async {
    final current = dataset;
    if (current == null) return;
    syncState = DataSyncState.checking;
    notifyListeners();
    try {
      final remote = await _repo.fetchRemote(current);
      if (remote != null) _setDataset(remote);
      syncState = remote != null ? DataSyncState.updated : DataSyncState.idle;
    } catch (_) {
      syncState = DataSyncState.failed;
    }
    notifyListeners();
  }

  Store? storeById(String id) => _byId[id];
  List<Store> get allStores => dataset?.stores ?? const [];

  OpenStatus statusOf(Store s) => openStatusAt(s.hours, now());

  // ---- 검색·필터 ----
  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void toggleCategory(StoreCategory c) {
    if (categories.contains(c)) {
      if (categories.length > 1) categories.remove(c);
    } else {
      categories.add(c);
    }
    notifyListeners();
  }

  void setOpenNowOnly(bool v) {
    openNowOnly = v;
    notifyListeners();
  }

  /// 현재 검색어·필터를 통과한 가게. 기준점에서 가까운 순.
  List<Store> filteredStores({GeoPoint? near}) {
    final q = normalizeQuery(query);
    final terms = q.isEmpty ? const <String>[] : [q];
    final result = [
      for (final s in allStores)
        if (categories.contains(s.category) &&
            terms.every(s.searchText.contains) &&
            (!openNowOnly || statusOf(s).isOpen))
          s,
    ];
    final origin = near ?? userLocation ?? daejeonCenter;
    result.sort((a, b) => distanceMeters(origin, GeoPoint(a.lat, a.lng))
        .compareTo(distanceMeters(origin, GeoPoint(b.lat, b.lng))));
    return result;
  }

  // ---- 위치 ----
  /// 현재 위치를 구해 대전 근처(30km 이내)면 [userLocation]으로 쓴다.
  /// 대전 밖이면 거리 기준점은 대전 중심으로 두고 null을 반환한다.
  Future<GeoPoint?> locate() async {
    locationError = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationError = '위치 서비스가 꺼져 있어요';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          locationError = '위치 권한이 없어 대전 중심에서 보여드려요';
        } else {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
          );
          final here = GeoPoint(p.latitude, p.longitude);
          if (distanceMeters(here, daejeonCenter) <= 30000) {
            userLocation = here;
          } else {
            userLocation = null;
            locationError = '현재 위치가 대전 밖이라 대전 중심 기준으로 보여드려요';
          }
        }
      }
    } catch (_) {
      locationError = '현재 위치를 가져오지 못했어요';
    }
    notifyListeners();
    return userLocation;
  }

  // ---- 찜 ----
  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    _prefs.setStringList('favorites', favorites.toList());
    notifyListeners();
  }

  List<Store> get favoriteStores => [for (final id in favorites) ?_byId[id]];

  // ---- 코스 ----
  void _saveCourses() {
    _prefs.setString('courses', jsonEncode([for (final c in courses) c.toJson()]));
    notifyListeners();
  }

  Course createCourse(String name) {
    final c = Course(id: _clock().microsecondsSinceEpoch.toString(), name: name, storeIds: []);
    courses.add(c);
    _saveCourses();
    return c;
  }

  void renameCourse(Course c, String name) {
    c.name = name;
    _saveCourses();
  }

  void deleteCourse(Course c) {
    courses.remove(c);
    _saveCourses();
  }

  void addToCourse(Course c, String storeId) {
    if (!c.storeIds.contains(storeId)) c.storeIds.add(storeId);
    _saveCourses();
  }

  void removeFromCourse(Course c, String storeId) {
    c.storeIds.remove(storeId);
    _saveCourses();
  }

  void setCourseOrder(Course c, List<String> ids) {
    c.storeIds
      ..clear()
      ..addAll(ids);
    _saveCourses();
  }

  /// 데이터 갱신으로 사라진 가게는 건너뛴다.
  List<Store> courseStores(Course c) => [for (final id in c.storeIds) ?_byId[id]];
}
