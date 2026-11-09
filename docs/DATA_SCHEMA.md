# 빵지순례 데이터 스키마

앱은 `data/stores.json` 하나만 읽는다. 이 파일은 `pipeline/`이 만든다.

```
data/
  raw/                 # 인허가 원본에서 추린 중간 결과 (커밋, diff 검수용)
  base/stores_base.json  # 인허가 데이터 기반 기본 목록 (pipeline 산출)
  curated/*.json       # 사람이 검수한 상세 정보 (수작업·조사 결과)
  stores.json          # base + curated 병합 결과. 앱 배포본
```

## stores.json

```jsonc
{
  "schemaVersion": 1,
  "dataVersion": "2026-11-09",          // 배포 데이터 버전(갱신 작업 실행일)
  "generatedAt": "2026-11-09T12:00:00+09:00",
  "coverage": {
    "region": "대전광역시",
    "storeCount": 812,
    "curatedCount": 48,                  // 상세정보가 검수된 가게 수
    "note": "인허가 데이터 기준 영업 중 업소. 누락·폐업 반영 지연 가능"
  },
  "stores": [Store]
}
```

## Store

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | string | 안정 ID. 인허가 기반이면 `lic-<관리번호>`, 수작업 단독이면 `cur-<slug>` |
| `name` | string | 상호 |
| `category` | `"bakery"｜"dessert"｜"frozen"` | 빵집·베이커리 / 케이크·마카롱·쿠키 등 디저트 / 도넛·아이스크림·빙수 |
| `franchise` | bool｜null | 프랜차이즈 여부(모르면 null) |
| `district` | string | 구 (`동구`,`중구`,`서구`,`유성구`,`대덕구`) |
| `address` | string | 도로명주소(없으면 지번) |
| `lat`,`lng` | number | WGS84 |
| `phone` | string｜null | |
| `instagram` | string｜null | 공식 계정 URL |
| `website` | string｜null | |
| `hours` | Hours｜null | null = 영업시간 미확인 |
| `holidayNote` | string｜null | 정기휴무·비정기 휴무 설명 원문 요약 (예: `매주 월요일 휴무`) |
| `products` | Product[] | 대표 상품. 비어 있으면 미확인 |
| `photos` | Photo[] | 사용 권한 있는 사진만. 비어 있으면 앱이 일러스트 표시 |
| `sources` | Source[] | 상세정보 출처 |
| `verifiedAt` | string｜null | 상세정보(시간·상품 등) 마지막 확인일 `YYYY-MM-DD`. null = 미검수 |
| `license` | object｜null | `{ "mgtNo", "kind": "제과점영업"｜"휴게음식점", "licensedAt", "status", "checkedAt" }` |

### Hours

요일 키 `mon,tue,wed,thu,fri,sat,sun`. 키가 없는 요일은 미확인.

```jsonc
{
  "mon": null,                                  // null = 휴무
  "tue": { "open": "08:00", "close": "22:00",
           "breaks": [["15:00", "16:00"]],      // 선택
           "lastOrder": "21:30" }               // 선택
}
```
`close`가 `open`보다 이르면 다음날 새벽 마감으로 해석한다(`"close": "02:00"`).

### Product
`{ "name": "튀김소보로", "price": 1700 | null, "note": "가격 확인 2026-11" | null }`

### Photo
`{ "url": "https://...", "credit": "점주 제공" }`

### Source
`{ "url": "https://...", "title": "공식 인스타그램 공지", "checkedAt": "2026-11-09" }`

## curated/*.json

`Store`의 부분집합 배열. 병합 키는 `id`(있으면) → 없으면 `match: { "name", "address" }`로 기본 목록과 정규화 비교.
매칭되지 않는 항목은 `lat`,`lng`,`category`,`address`,`district`가 모두 있어야 단독 가게로 추가된다.
curated 값이 base 값을 덮어쓴다(`null`은 덮어쓰지 않음, `closed: true`면 목록에서 제외).
