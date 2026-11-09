"""행정안전부 지방행정 인허가 파일(대전광역시)을 내려받아 영업 중 업소만 data/raw/ 에 저장한다.

출처: 공공데이터포털 파일데이터 '행정안전부_식품_제과점영업'(15044973),
'행정안전부_식품_휴게음식점'(15006730). 두 데이터셋의 제공형태는 '기관자체에서 다운로드'이며
실제 파일은 file.localdata.go.kr 에서 지역(개방자치단체)별로 받는다. 인증키가 필요 없다.

출력 (결정적, 관리번호 순 정렬):
  data/raw/bakeries.csv, data/raw/rest_cafes.csv  — 영업/정상 업소만, 필요한 열만
  data/raw/meta.json                               — 출처·건수·원본 최종 갱신시점
"""
from __future__ import annotations

import csv
import io
import sys
import time

import requests

from common import (
    CACHE_DIR,
    DAEJEON_ORG_CODE,
    RAW_COLUMNS,
    RAW_DIR,
    REGION,
    SOURCES,
    now_kst,
    write_json,
)

USER_AGENT = "bbangji-sunrye-pipeline/1.0 (+https://github.com/kimbongjun79/bbangji-sunrye)"
OPEN_STATUS_CODE = "01"  # 영업상태코드 01 = 영업/정상
REQUIRED_HEADERS = ("관리번호", "영업상태코드", "사업장명", "도로명주소", "지번주소", "좌표정보(X)", "좌표정보(Y)")


def download(kind: str) -> bytes:
    src = SOURCES[kind]
    session = requests.Session()
    # 다운로드 서버는 공공데이터포털 데이터셋 페이지에서 넘어온 요청만 받는다(Referer 확인).
    session.headers.update({"User-Agent": USER_AGENT, "Referer": src["dataset"]})
    url = f"{src['download']}?orgCode={DAEJEON_ORG_CODE}"
    last_error = ""
    for attempt in range(1, 5):
        try:
            # 사이트의 다운로드 횟수 확인 절차를 그대로 따른다(429 = 잠시 후 재시도).
            check = session.get("https://file.localdata.go.kr/file/validate/download-count", timeout=30)
            if check.status_code == 429:
                last_error = f"download-count 429: {check.text.strip()[:200]}"
            else:
                check.raise_for_status()
                resp = session.get(url, timeout=600)
                resp.raise_for_status()
                disposition = resp.headers.get("Content-Disposition", "")
                if "attachment" not in disposition:
                    raise RuntimeError(f"CSV 첨부가 아닌 응답: {resp.headers.get('Content-Type')} {resp.text[:200]!r}")
                return resp.content
        except (requests.RequestException, RuntimeError) as e:
            last_error = str(e)
        wait = 30 * attempt
        print(f"[fetch] {kind} 시도 {attempt} 실패: {last_error} — {wait}s 후 재시도", file=sys.stderr)
        time.sleep(wait)
    raise SystemExit(f"[fetch] {kind} 다운로드 실패: {last_error}")


def decode(content: bytes) -> str:
    for enc in ("utf-8-sig", "cp949"):
        try:
            return content.decode(enc)
        except UnicodeDecodeError:
            continue
    raise SystemExit("[fetch] CSV 인코딩을 알 수 없음")


def trim(kind: str, text: str) -> tuple[list[dict], dict]:
    reader = csv.DictReader(io.StringIO(text))
    missing = [h for h in REQUIRED_HEADERS if h not in (reader.fieldnames or [])]
    if missing:
        raise SystemExit(f"[fetch] {kind} CSV 열 구조가 바뀜: {missing} 없음. 열: {reader.fieldnames}")
    total = 0
    not_open = 0
    outside = 0
    last_update = ""
    rows: dict[str, dict] = {}
    for r in reader:
        total += 1
        last_update = max(last_update, (r.get("데이터갱신시점") or "").strip())
        if (r.get("영업상태코드") or "").strip() != OPEN_STATUS_CODE:
            not_open += 1
            continue
        road = (r.get("도로명주소") or "").strip()
        jibun = (r.get("지번주소") or "").strip()
        if REGION not in road and REGION not in jibun and (road or jibun):
            outside += 1
            continue
        mgt = r["관리번호"].strip()
        rows[mgt] = {
            "mgtNo": mgt,
            "kind": kind,
            "name": " ".join(r["사업장명"].split()),
            "bizType": (r.get("업태구분명") or "").strip(),
            "licensedAt": (r.get("인허가일자") or "").strip(),
            "status": (r.get("영업상태명") or "").strip(),
            "roadAddress": " ".join(road.split()),
            "jibunAddress": " ".join(jibun.split()),
            "phone": (r.get("전화번호") or "").strip(),
            "x": (r.get("좌표정보(X)") or "").strip(),
            "y": (r.get("좌표정보(Y)") or "").strip(),
            "orgCode": (r.get("개방자치단체코드") or "").strip(),
        }
    stats = {
        "totalRows": total,
        "notOpen": not_open,
        "outsideRegion": outside,
        "open": len(rows),
        "sourceLastUpdated": last_update or None,
    }
    return [rows[k] for k in sorted(rows)], stats


def write_raw(slug: str, rows: list[dict]) -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with (RAW_DIR / f"{slug}.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=RAW_COLUMNS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    use_cache = "--cache" in sys.argv  # 개발용: 이전에 받은 원본 재사용
    fetched_at = now_kst()
    meta = {"fetchedAt": fetched_at.isoformat(), "region": REGION, "orgCode": DAEJEON_ORG_CODE, "sources": {}}
    for kind, src in SOURCES.items():
        cache = CACHE_DIR / f"{src['slug']}_{DAEJEON_ORG_CODE}.csv"
        if use_cache and cache.exists():
            content = cache.read_bytes()
        else:
            content = download(kind)
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            cache.write_bytes(content)
        rows, stats = trim(kind, decode(content))
        if not rows:
            raise SystemExit(f"[fetch] {kind}: 영업 중 업소가 0건 — 원본 이상으로 판단하고 중단")
        write_raw(src["slug"], rows)
        meta["sources"][kind] = {
            "dataset": src["dataset"],
            "download": f"{src['download']}?orgCode={DAEJEON_ORG_CODE}",
            "rawFile": f"data/raw/{src['slug']}.csv",
            **stats,
        }
        print(f"[fetch] {kind}: 전체 {stats['totalRows']}행 → 영업 중 {stats['open']}건")
    write_json(RAW_DIR / "meta.json", meta)


if __name__ == "__main__":
    main()
