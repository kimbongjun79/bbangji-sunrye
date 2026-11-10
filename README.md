<div align="center">

<img src="docs/images/icon.png" width="96" alt="빵지순례 아이콘" />

# 빵지순례

**대전의 빵집·디저트·도넛·아이스크림·빙수 가게만 모아 보여주는 지도 앱**

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-15%2B-000000?logo=apple&logoColor=white)
![Kakao Map](https://img.shields.io/badge/Kakao%20Maps%20SDK-v2-FFCD00?logo=kakao&logoColor=black)
![Data](https://img.shields.io/badge/가게-982곳-C98B4E)
![Update](https://img.shields.io/badge/데이터-매월%20자동%20갱신-5B3A22)

</div>

<p align="center">
  <img src="docs/images/map.png" width="300" alt="빵지순례 지도 화면" />
</p>

> 다른 상호는 지우고, 빵·디저트 가게만 남긴 지도.
> 개인·지인용으로 만든 비공식 앱입니다.

<div align="center">

[![Android APK 다운로드](https://img.shields.io/badge/Android-APK%20다운로드-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/kimbongjun79/bbangji-sunrye/releases/latest/download/bbangji-sunrye.apk)
[![iPhone IPA 다운로드](https://img.shields.io/badge/iPhone-IPA%20다운로드-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/kimbongjun79/bbangji-sunrye/releases/latest/download/bbangji-sunrye.ipa)

<sub>최신 버전 · Android 7.0 이상 · iOS 15 이상 · <a href="https://github.com/kimbongjun79/bbangji-sunrye/releases">모든 버전 보기</a></sub>

</div>

### 📲 Android 설치

1. 휴대폰에서 위 **APK 다운로드** 버튼을 누릅니다.
2. 받은 `bbangji-sunrye.apk`를 엽니다. ‘출처를 알 수 없는 앱’ 안내가 나오면 설치를 허용합니다.
3. 처음 실행할 때 위치 권한을 허용하면 내 주변 가게부터 보여줍니다.

새 버전은 같은 방법으로 덮어 설치하면 됩니다. 찜과 코스는 그대로 남습니다. 가게 데이터는 앱을 열 때 자동으로 최신화됩니다.

### 🍎 iPhone 설치 (Windows PC + 무료 Apple ID)

아이폰은 앱스토어 밖의 앱을 바로 설치할 수 없어서, PC에서 **내 Apple ID로 서명해 설치**합니다. 무료 Apple ID로 설치한 앱은 **7일마다 다시 서명**해야 합니다.

1. PC에 [iTunes](https://www.apple.com/kr/itunes/)와 [iCloud](https://support.apple.com/ko-kr/103232)를 애플 홈페이지 설치본으로 깔고, [Sideloadly](https://sideloadly.io/)를 설치합니다.
2. 위 **IPA 다운로드** 버튼으로 `bbangji-sunrye.ipa`를 받습니다.
3. 아이폰을 USB로 PC에 연결하고 아이폰에서 ‘이 컴퓨터 신뢰’를 누릅니다.
4. Sideloadly에 IPA를 끌어다 놓고 Apple ID를 입력한 뒤 **Start**를 누릅니다.
5. 아이폰 **설정 → 일반 → VPN 및 기기 관리**에서 내 Apple ID를 신뢰합니다.
6. iOS 16 이상은 **설정 → 개인정보 보호 및 보안 → 개발자 모드**를 켜고 재시동합니다.

7일이 지나 앱이 열리지 않으면 4번을 다시 하면 됩니다(찜·코스 유지). Sideloadly의 자동 갱신을 켜 두면 PC와 아이폰이 같은 와이파이에 있을 때 자동으로 다시 서명합니다.

> 지도는 번들 ID `com.bbangji.sunrye`로만 인증됩니다. 설치 중 “App ID가 사용 중”이라는 오류가 나면 관리자에게 알려주세요(다른 번들 ID를 카카오에 추가 등록해야 합니다).

## 🥐 주요 기능

| | 기능 | 설명 |
|---|---|---|
| 🗺️ | **빵·디저트 전용 지도** | 기본 지도의 상가·시설 표시를 숨기고 대상 가게만 마커로 표시. 동네 이름·도로·지하철역은 남겨 위치 파악 |
| 🧁 | **업종 필터** | 빵집 / 디저트 / 도넛·빙수, **영업 중**만 보기 |
| 🔎 | **가게·상품 검색** | `소금빵`, `성심당`, `휘낭시에`처럼 가게 이름이나 대표 상품으로 검색 |
| 📍 | **내 주변** | 현재 위치 기준 거리순 목록, 지도·목록 전환 |
| 🏬 | **같은 건물 묶음** | 백화점처럼 한 건물에 모인 가게는 `3곳`으로 묶고 눌러서 선택 |
| 🕘 | **가게 상세** | 요일별 영업시간·브레이크타임·라스트오더, 휴무일, 대표 상품과 가격, 전화, 인스타그램, 출처와 확인일 |
| 🧭 | **길찾기** | 네이버지도·카카오맵 앱으로 바로 연결 |
| ❤️ | **찜** | 로그인 없이 휴대폰에 저장 |
| 🚶 | **빵지순례 코스** | 가게를 담아 순서 편집, **방문 순서 자동 추천**(직선거리 기준), 다음 가게로 길찾기 |

모르는 정보는 추측하지 않고 `미확인`으로 표시합니다. ‘영업 중’은 등록된 영업시간 기준이라 임시휴무는 반영되지 않을 수 있습니다.

## 🍞 데이터

```
행정안전부 인허가 데이터 (제과점영업·휴게음식점, 대전 전체)
        │  매월 1일 GitHub Actions가 자동 수집·분류·좌표 변환
        ▼
data/base/stores_base.json ──┐
                             ├─▶ data/stores.json ──▶ 앱이 실행 시 내려받아 저장
data/curated/*.json ─────────┘     (main 브랜치 = 검수 완료본)
 (영업시간·상품·가격·인스타그램, 출처·확인일 포함)
```

- **가게 목록**: [공공데이터포털](https://www.data.go.kr/data/15044973/fileData.do) 지방행정 인허가 데이터 중 대전의 영업 중 업소. 이용허락범위 제한 없음.
- **상세 정보**: 공식 사이트·공개된 플레이스 정보·블로그·뉴스에서 확인한 내용만 출처 링크와 함께 기록.
- **사진**: 사용 권한이 있는 사진만 씁니다. 권한이 없으면 업종 일러스트로 대체합니다.
- **검수**: 월간 작업은 결과를 바로 반영하지 않고 **PR**로 올립니다. 병합해야 앱에 반영됩니다.

| 구분 | 수 |
|---|---:|
| 등록 가게 | 982 |
| 빵집·베이커리 | 654 |
| 디저트 | 184 |
| 도넛·아이스크림·빙수 | 147 |
| 상세 정보 검수 | 44 |

<sub>2026-11-09 기준. 신규 개업·폐업은 인허가 데이터 반영 시점에 따라 늦어질 수 있습니다.</sub>

## 📁 구조

| 경로 | 내용 |
|---|---|
| [`app/`](app) | Flutter 앱 |
| [`app/third_party/kakao_map_sdk/`](app/third_party/kakao_map_sdk) | 기본 지도 표시 숨김 기능을 추가한 지도 플러그인 사본 ([변경 내역](app/third_party/kakao_map_sdk/BBANGJI_CHANGES.md)) |
| [`data/`](data) | 원본 요약·기본 목록·상세 정보·배포 데이터 |
| [`pipeline/`](pipeline) | 수집·분류·병합 스크립트 ([설명](pipeline/README.md)) |
| [`docs/DATA_SCHEMA.md`](docs/DATA_SCHEMA.md) | 데이터 형식 |
| [`.github/workflows/monthly-update.yml`](.github/workflows/monthly-update.yml) | 월간 자동 갱신 |
| [`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml) | 아이폰 빌드(맥 없이 GitHub에서 IPA 생성) |

## 🛠️ 빌드

필요: Flutter SDK, JDK 17, Android SDK, 카카오 개발자 콘솔의 **네이티브 앱 키**, 서명 키.

`keys/` 폴더(서명 키 `key.properties`, 카카오 키 `kakao.env`)는 저장소에 올리지 않습니다.

```bash
cd app
flutter test
flutter build apk --release --target-platform android-arm,android-arm64 \
  --dart-define=KAKAO_NATIVE_KEY=<네이티브 앱 키>
```

- 카카오맵 SDK는 ARM 전용이라 APK에 ARM 라이브러리만 담습니다. x86_64 에뮬레이터에서는 ARM 변환으로 실행됩니다.
- 카카오 개발자 콘솔 **[앱] → [플랫폼 키] → [네이티브 앱 키]**에 패키지명 `com.bbangji.sunrye`·서명 키의 키 해시(Android), 번들 ID `com.bbangji.sunrye`(iOS)를 등록하고, **[카카오맵] → [사용 설정]**을 켜야 지도가 표시됩니다.
- **아이폰**: 맥이 없어도 GitHub Actions의 `iOS 빌드` 워크플로를 실행하면 서명 없는 IPA와 시뮬레이터 실행 화면이 만들어집니다(저장소 시크릿 `KAKAO_NATIVE_KEY` 필요). `v*` 태그를 올리면 릴리스에 IPA가 첨부됩니다. iOS 지도 SDK는 기본 지도 표시를 종류별로 끌 수 없어, 아이폰에서는 지하철역 등 기본 표시가 모두 숨겨집니다.

### 데이터 직접 갱신

```bash
pip install -r pipeline/requirements.txt
python pipeline/fetch.py && python pipeline/build_base.py && python pipeline/merge.py
```

결과 요약은 `pipeline/out/report.md`에 생깁니다. 확인일이 90일 지난 상세 정보도 여기에 표시됩니다.

## ⚠️ 알아두기

- 개인·지인용으로 만든 비공식 앱입니다. 각 가게·카카오·네이버와 관계없습니다.
- 가게 정보는 바뀔 수 있습니다. 방문 전에 가게 공지를 확인하세요.
- 코스 추천은 직선거리 기준이며 도로·교통·영업시간을 고려하지 않습니다.
- 찜과 코스는 휴대폰에만 저장되어, 앱을 지우면 함께 사라집니다.
- 잘못된 정보나 빠진 가게는 [Issues](../../issues)로 알려주세요.

<div align="center"><sub>Made with 🥐 in Daejeon</sub></div>
