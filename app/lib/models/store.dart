enum StoreCategory {
  bakery('bakery', '빵집'),
  dessert('dessert', '디저트'),
  frozen('frozen', '도넛·아이스크림·빙수');

  const StoreCategory(this.key, this.label);
  final String key;
  final String label;

  static StoreCategory parse(String? key) =>
      values.firstWhere((c) => c.key == key, orElse: () => bakery);
}

/// 요일 키. DateTime.weekday(1=월)와 index+1이 일치한다.
const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// "HH:mm" → 자정 기준 분.
int parseHm(String hm) {
  final parts = hm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

class DayHours {
  const DayHours({required this.open, required this.close, this.breaks = const [], this.lastOrder});

  final String open;
  final String close;
  final List<(String, String)> breaks;
  final String? lastOrder;

  int get openMin => parseHm(open);

  /// 다음날 새벽 마감이면 24h를 더한 값.
  int get closeMin {
    final c = parseHm(close);
    return c <= openMin ? c + 24 * 60 : c;
  }

  factory DayHours.fromJson(Map<String, dynamic> j) => DayHours(
        open: j['open'] as String,
        close: j['close'] as String,
        breaks: [
          for (final b in (j['breaks'] as List? ?? const []))
            ((b as List)[0] as String, b[1] as String),
        ],
        lastOrder: j['lastOrder'] as String?,
      );
}

/// 요일별 영업시간. [days]에 키가 없으면 미확인, 값이 null이면 휴무.
class Hours {
  const Hours(this.days);
  final Map<String, DayHours?> days;

  bool isKnown(int weekdayIndex) => days.containsKey(weekdayKeys[weekdayIndex]);
  DayHours? of(int weekdayIndex) => days[weekdayKeys[weekdayIndex]];

  factory Hours.fromJson(Map<String, dynamic> j) => Hours({
        for (final e in j.entries)
          if (weekdayKeys.contains(e.key))
            e.key: e.value == null ? null : DayHours.fromJson(e.value as Map<String, dynamic>),
      });
}

class Product {
  const Product({required this.name, this.price, this.note});
  final String name;
  final int? price;
  final String? note;

  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(name: j['name'] as String, price: (j['price'] as num?)?.toInt(), note: j['note'] as String?);
}

class Photo {
  const Photo({required this.url, this.credit});
  final String url;
  final String? credit;

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(url: j['url'] as String, credit: j['credit'] as String?);
}

class SourceRef {
  const SourceRef({required this.url, this.title, this.checkedAt});
  final String url;
  final String? title;
  final String? checkedAt;

  factory SourceRef.fromJson(Map<String, dynamic> j) =>
      SourceRef(url: j['url'] as String, title: j['title'] as String?, checkedAt: j['checkedAt'] as String?);
}

class Store {
  Store({
    required this.id,
    required this.name,
    required this.category,
    required this.franchise,
    required this.district,
    required this.address,
    required this.lat,
    required this.lng,
    this.phone,
    this.instagram,
    this.website,
    this.hours,
    this.holidayNote,
    this.products = const [],
    this.photos = const [],
    this.sources = const [],
    this.verifiedAt,
    this.licenseCheckedAt,
  }) : searchText = _normalize([name, district, address, for (final p in products) p.name].join(' '));

  final String id;
  final String name;
  final StoreCategory category;
  final bool? franchise;
  final String district;
  final String address;
  final double lat;
  final double lng;
  final String? phone;
  final String? instagram;
  final String? website;
  final Hours? hours;
  final String? holidayNote;
  final List<Product> products;
  final List<Photo> photos;
  final List<SourceRef> sources;
  final String? verifiedAt;
  final String? licenseCheckedAt;

  /// 검색용 정규화 문자열(공백 제거, 소문자).
  final String searchText;

  bool get isCurated => verifiedAt != null || products.isNotEmpty || hours != null;

  factory Store.fromJson(Map<String, dynamic> j) {
    final license = j['license'] as Map<String, dynamic>?;
    return Store(
      id: j['id'] as String,
      name: j['name'] as String,
      category: StoreCategory.parse(j['category'] as String?),
      franchise: j['franchise'] as bool?,
      district: (j['district'] as String?) ?? '',
      address: (j['address'] as String?) ?? '',
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      phone: j['phone'] as String?,
      instagram: j['instagram'] as String?,
      website: j['website'] as String?,
      hours: j['hours'] == null ? null : Hours.fromJson(j['hours'] as Map<String, dynamic>),
      holidayNote: j['holidayNote'] as String?,
      products: [for (final p in (j['products'] as List? ?? const [])) Product.fromJson(p as Map<String, dynamic>)],
      photos: [for (final p in (j['photos'] as List? ?? const [])) Photo.fromJson(p as Map<String, dynamic>)],
      sources: [for (final s in (j['sources'] as List? ?? const [])) SourceRef.fromJson(s as Map<String, dynamic>)],
      verifiedAt: j['verifiedAt'] as String?,
      licenseCheckedAt: license?['checkedAt'] as String?,
    );
  }
}

String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

String normalizeQuery(String s) => _normalize(s);

class StoreDataset {
  const StoreDataset({
    required this.dataVersion,
    required this.generatedAt,
    required this.stores,
    required this.coverageNote,
    required this.curatedCount,
  });

  final String dataVersion;
  final String? generatedAt;
  final List<Store> stores;
  final String? coverageNote;
  final int curatedCount;

  factory StoreDataset.fromJson(Map<String, dynamic> j) {
    final coverage = j['coverage'] as Map<String, dynamic>? ?? const {};
    final stores = [for (final s in j['stores'] as List) Store.fromJson(s as Map<String, dynamic>)];
    return StoreDataset(
      dataVersion: j['dataVersion'] as String,
      generatedAt: j['generatedAt'] as String?,
      stores: stores,
      coverageNote: coverage['note'] as String?,
      curatedCount: (coverage['curatedCount'] as num?)?.toInt() ?? stores.where((s) => s.isCurated).length,
    );
  }
}
