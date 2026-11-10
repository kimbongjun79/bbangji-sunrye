# 빵지순례 변경 사항

원본: [kakao_map_sdk 1.3.1](https://pub.dev/packages/kakao_map_sdk) (BSD 3-Clause, `LICENSE` 참고)

- `KakaoMapController.setVisiblePoiCategory(categories, visible)` 추가 (Android 전용).
  Kakao Maps SDK의 `KakaoMap.setVisiblePoiCategory(PoiCategory, boolean)`를 호출해
  기본 지도에 그려지는 상가·시설 POI를 숨긴다.
  - Dart: `lib/controller/controller.dart`, `lib/controller/controller_implement.dart`
  - Android: `android/.../controller/KakaoMapControllerHandler.kt`, `KakaoMapController.kt`
  - iOS·Web 미구현(호출 시 예외 → 앱에서 무시).

원본 패키지를 올릴 때는 위 변경을 다시 적용하거나 원본에 기능 제안 후 교체한다.
