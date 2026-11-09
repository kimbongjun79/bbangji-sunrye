# 데이터 파이프라인

대전광역시 인허가 데이터에서 빵집·디저트·도넛/아이스크림/빙수 가게를 골라 `data/stores.json`(앱 배포본)을 만든다.
스키마는 `docs/DATA_SCHEMA.md` 를 따른다.

```
fetch.py       인허가 파일 다운로드 → data/raw/bakeries.csv, rest_cafes.csv, meta.json
build_base.py  분류·좌표 변환·중복 묶음 → data/base/stores_base.json
merge.py       base + data/curated/*.json → data/stores.json, pipeline/out/report.md
rules.py       포함/제외·카테고리·프랜차이즈 판정 규칙
```

## 데이터 출처

| 업종 | 공공데이터포털 데이터셋 | 실제 다운로드 |
|---|---|---|
| 제과점영업 | [행정안전부_식품_제과점영업 (15044973)](https://www.data.go.kr/data/15044973/fileData.do) | `https://file.localdata.go.kr/file/download/bakeries/info?orgCode=6300000_ALL` |
| 휴게음식점 | [행정안전부_식품_휴게음식점 (15006730)](https://www.data.go.kr/data/15006730/fileData.do) | `https://file.localdata.go.kr/file/download/rest_cafes/info?orgCode=6300000_ALL` |

- 제공: 행정안전부(지역디지털협력과). 이용허락범위 **제한 없음**, 무료. 매일 갱신(2일 전 기준).
- 2026-01-25 부터 지방행정 인허가 데이터는 공공데이터포털로 통합됐고, 옛 LOCALDATA 누리집은 2026-04-15 에 종료됐다.
  공공데이터포털 파일데이터의 제공형태가 '기관자체에서 다운로드'라서 파일은 `file.localdata.go.kr` 에서 받는다.
  `orgCode=6300000_ALL` 은 대전광역시 전체(본청+5개 구)다.
- **인증키가 필요 없다.** 다운로드 서버는 공공데이터포털 데이터셋 페이지에서 넘어온 요청만 받으므로
  `fetch.py` 는 해당 데이터셋 페이지를 `Referer` 로 보내고, 사이트 스크립트와 같은 순서로 다운로드 횟수 확인
  (`/file/validate/download-count`, 429 면 잠시 후 재시도)을 거친다. robots.txt 는 전체 허용이다.
- 좌표는 데이터셋 설명대로 Bessel 중부원점TM(EPSG:5174)이며 WGS84 로 바꾼다. 성심당 본점으로 확인했다.
- 같은 데이터는 OpenAPI 로도 제공된다(예: [제과점영업 조회서비스 15155252](https://www.data.go.kr/data/15155252/openapi.do),
  `apis.data.go.kr/1741000/bakeries`). 이쪽은 개인 serviceKey 가 필요해서 쓰지 않는다.
  파일 다운로드 경로가 막히면 이 API 로 옮겨야 하며, 그때는 활용신청한 키가 필요하다.

## 로컬 실행

Python 3.10 이상.

```bash
pip install -r pipeline/requirements.txt
python pipeline/fetch.py        # 약 10초, 원본은 pipeline/.cache/ 에도 남는다
python pipeline/build_base.py
python pipeline/merge.py        # 결과 요약은 pipeline/out/report.md
```

- curated 만 고쳤으면 `python pipeline/merge.py` 만 다시 돌리면 된다.
- `python pipeline/fetch.py --cache` 는 `pipeline/.cache/` 의 원본을 다시 써서 다운로드를 건너뛴다(규칙 조정용).
- `merge.py` 는 가게 목록이 이전 `data/stores.json` 과 같으면(`license.checkedAt` 만 다르면) 파일을 다시 쓰지 않는다.
- `pipeline/.cache/`, `pipeline/out/` 은 커밋하지 않는다.

## 분류 규칙 요약 (`rules.py`)

- **제과점영업**: 모두 포함, 기본 `bakery`. 단 상호가 커피 프랜차이즈·커피 중심(메가커피, 컴포즈, '커피' 등)이고
  빵·디저트 단어가 없으면 제외(보고서 '사람 확인용'에 목록이 나온다).
- **휴게음식점**: 상호에 빵·디저트·아이스크림 단어가 있거나 업태가 `아이스크림`·`떡카페`·`과자점` 일 때만 포함.
  일반 커피숍은 제외. 업태 `편의점`·`푸드트럭`·`키즈카페`, 호떡·붕어빵·계란빵·찐빵 같은 길거리 간식, 휴게소 매대,
  탕후루, 어묵 가게도 제외.
- 공통 제외 단어: 떡볶이, 피자, 치킨, 김밥, 분식, 만두, 무인/할인 아이스크림점, 편의점 상호 등.
- 카테고리 우선순위: 도넛·아이스크림·젤라또·빙수·요거트 → `frozen` > 베이커리·빵·제과·브레드·오븐·베이글·꽈배기 → `bakery`
  > 케이크·마카롱·쿠키·디저트·타르트·떡·와플·마들렌 등 → `dessert` > 인허가 종류 기본값.
- 프랜차이즈: 목록(파리바게뜨, 뚜레쥬르, 던킨, 배스킨라빈스, 설빙, 크리스피크림, 요아정, 디저트39, 와플대학 …)에 있으면 `true`,
  성심당 계열은 `false`, 나머지는 `null`(모름).
- 같은 좌표에 끝 번호만 다른 같은 상호(예: '성심당 롯데대전점1'~'6')는 가장 오래된 인허가 하나로 묶고 이름 끝 번호를 뗀다.
  묶여 사라진 id 는 `stores_base.json` 의 `aliases` 에 남아 curated 의 id 매칭에 쓰인다.
- 전화번호는 지역번호·대표번호만 싣는다. 휴대전화(01X)는 개인 번호일 수 있어 뺀다.
- 좌표가 없거나 대전 범위 밖으로 변환되는 업소는 제외하고 보고서에 남긴다.

규칙이 틀린 가게는 `data/curated/*.json` 에서 고친다: `category` 를 덮어쓰거나, `closed: true` 로 빼거나,
빠진 가게를 `lat,lng,category,address,district` 를 갖춘 단독 항목(`cur-…` id)으로 추가한다.

## 월간 자동 갱신과 검수

`.github/workflows/monthly-update.yml`

1. 매월 1일 03:00 KST(예약은 매달 28~31일 18:00 UTC 에 깨어나 KST 날짜가 1일일 때만 진행) 또는 Actions 탭에서 수동 실행.
2. `fetch.py → build_base.py → merge.py` 실행. 하나라도 실패하면 거기서 끝나고 아무것도 push 하지 않는다.
3. `data/stores.json` 이 바뀌었으면 `data-update/YYYY-MM` 브랜치에 커밋하고 `main` 대상 PR 을 열거나 갱신한다.
   PR 본문은 `report.md`(카테고리×구 집계, 신규/제외 가게, curated 미매칭·검증 실패, 90일 넘은 검수 항목,
   규칙상 뺀 제과점 목록)다. 같은 내용이 실행 요약(Step Summary)에도 남는다.
4. **사람이 PR 을 검토하고 병합해야 앱에 반영된다.** 앱은 `main` 의 `data/stores.json` 을 내려받는다.
   검토 때 볼 것: 신규·제외 가게가 상식적인지, 신규 가게 카테고리, curated 미매칭·검증 실패 항목, 재확인 필요 목록.

### 사전 준비 (GitHub 저장소 설정)

- Settings → Actions → General → Workflow permissions: **Read and write permissions**,
  그리고 **Allow GitHub Actions to create and approve pull requests** 체크. (없으면 PR 생성 단계가 403 으로 실패)
- 권장: `main` 브랜치 보호(직접 push 금지, PR 필수).
- 별도 secret·API 키는 필요 없다(`GITHUB_TOKEN` 만 사용).

## 알려진 한계

- 인허가 데이터는 신고 기준이라 폐업 신고가 늦으면 문 닫은 가게가 남고, 개업 직후 가게는 늦게 들어온다.
- 휴게음식점은 상호만 보고 고르므로 이름에 단서가 없는 디저트 카페(예: '카페 ○○' 인 케이크 전문점)는 빠진다.
  반대로 '빵'·'떡'이 들어간 다른 업종이 섞일 수 있다. curated 로 보완한다.
- 키워드 우선순위 때문에 '찹쌀도너츠&브래드' 는 `frozen`, '카롱제과' 는 `bakery` 처럼 애매한 경우가 있다.
- 일반음식점·즉석판매제조가공업으로 신고한 빵집·디저트 가게는 대상 업종이 아니라서 빠진다.
- 백화점·대형마트 안의 매장은 인허가 단위로 나뉘어 같은 건물에 여러 점이 찍힌다(같은 상호·같은 좌표만 묶는다).
