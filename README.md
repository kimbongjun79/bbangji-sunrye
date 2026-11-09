# 빵지순례

대전의 빵집·베이커리, 디저트 전문점, 도넛·아이스크림·빙수 전문점만 보여주는 개인·지인용 지도 앱(Flutter, Android 우선).

| 경로 | 내용 |
|---|---|
| `app/` | Flutter 앱 |
| `data/stores.json` | 앱이 내려받는 배포 데이터 (main 브랜치 = 검수 완료본) |
| `data/curated/` | 출처·확인일이 있는 상세정보(영업시간·상품·가격·인스타그램) |
| `pipeline/` | 인허가 데이터 수집·분류·병합 스크립트 ([README](pipeline/README.md)) |
| `docs/DATA_SCHEMA.md` | 데이터 형식 |
| `.github/workflows/monthly-update.yml` | 매월 1일 자동 갱신 → PR 생성(병합 = 검수 승인) |

## 앱 빌드

필요: Flutter SDK, JDK 17, Android SDK, `keys/key.properties`(서명 키), `keys/kakao.env`(카카오 네이티브 앱 키). `keys/`는 저장소에 올리지 않는다.

```bash
cd app
flutter build apk --release --target-platform android-arm,android-arm64 \
  --dart-define=KAKAO_NATIVE_KEY=<keys/kakao.env의 값>
```

카카오맵 SDK는 ARM만 지원해 APK에 ARM 라이브러리만 담는다. x86_64 에뮬레이터에서는 ARM 변환으로 실행된다.

카카오 개발자 콘솔의 Android 플랫폼에는 패키지명 `com.bbangji.sunrye`와 서명 키의 키 해시를 등록해야 한다.

## 데이터 갱신

앱은 시작할 때 `https://raw.githubusercontent.com/kimbongjun79/bbangji-sunrye/main/data/stores.json`을 확인해 바뀌었으면 받아 기기에 저장한다. 실패하면 마지막으로 받은 데이터나 앱에 포함된 데이터를 쓴다.

월간 작업은 가게 목록(신규·폐업)만 자동으로 갱신한다. 영업시간·상품·가격은 `data/curated/`를 사람이 확인해 고치며, 갱신 PR 보고서에 확인일이 90일 지난 항목이 표시된다.
