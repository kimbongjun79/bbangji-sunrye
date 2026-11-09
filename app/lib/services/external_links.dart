import 'package:url_launcher/url_launcher.dart';

import '../models/store.dart';
import 'geo.dart';

const _appName = 'com.bbangji.sunrye';

enum MapApp { naver, kakao }

/// 외부 지도 앱 길찾기. 앱이 없으면 웹 지도로 연다.
Future<bool> openDirections(MapApp app, Store to, {GeoPoint? from, String fromName = '출발지'}) async {
  final name = Uri.encodeComponent(to.name);
  final Uri appUri;
  final Uri webUri;
  switch (app) {
    case MapApp.naver:
      final start = from == null ? '' : 'slat=${from.lat}&slng=${from.lng}&sname=${Uri.encodeComponent(fromName)}&';
      appUri = Uri.parse('nmap://route/walk?${start}dlat=${to.lat}&dlng=${to.lng}&dname=$name&appname=$_appName');
      webUri = Uri.parse('https://map.naver.com/p/directions/-/${to.lng},${to.lat},$name,,/-/walk');
    case MapApp.kakao:
      final start = from == null ? '' : 'sp=${from.lat},${from.lng}&';
      appUri = Uri.parse('kakaomap://route?${start}ep=${to.lat},${to.lng}&by=FOOT');
      webUri = Uri.parse('https://map.kakao.com/link/to/$name,${to.lat},${to.lng}');
  }
  try {
    if (await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication)) return true;
  } catch (_) {
    // 앱 미설치
  }
  return launchUrl(webUri, mode: LaunchMode.externalApplication);
}

Future<bool> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

Future<bool> callPhone(String phone) => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')));
