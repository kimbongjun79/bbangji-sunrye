"""파이프라인 공통 경로·상수·입출력 도우미."""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
RAW_DIR = DATA / "raw"
BASE_PATH = DATA / "base" / "stores_base.json"
CURATED_DIR = DATA / "curated"
STORES_PATH = DATA / "stores.json"
OUT_DIR = ROOT / "pipeline" / "out"
CACHE_DIR = ROOT / "pipeline" / ".cache"

KST = timezone(timedelta(hours=9))

REGION = "대전광역시"
DISTRICTS = ("동구", "중구", "서구", "유성구", "대덕구")
# 개방자치단체코드 → 구 (주소에서 구를 못 찾을 때만 사용)
ORG_DISTRICT = {
    "3640000": "동구",
    "3650000": "중구",
    "3660000": "서구",
    "3670000": "유성구",
    "3680000": "대덕구",
}

# 행정안전부 지방행정 인허가 파일 다운로드 (공공데이터포털 파일데이터의 '기관자체 다운로드' 경로)
SOURCES = {
    "제과점영업": {
        "slug": "bakeries",
        "dataset": "https://www.data.go.kr/data/15044973/fileData.do",
        "download": "https://file.localdata.go.kr/file/download/bakeries/info",
    },
    "휴게음식점": {
        "slug": "rest_cafes",
        "dataset": "https://www.data.go.kr/data/15006730/fileData.do",
        "download": "https://file.localdata.go.kr/file/download/rest_cafes/info",
    },
}
DAEJEON_ORG_CODE = "6300000_ALL"
LICENSE_NOTE = "행정안전부 지방행정 인허가 데이터(공공데이터포털, 이용허락범위 제한 없음)"

RAW_COLUMNS = (
    "mgtNo",
    "kind",
    "name",
    "bizType",
    "licensedAt",
    "status",
    "roadAddress",
    "jibunAddress",
    "phone",
    "x",
    "y",
    "orgCode",
)


def now_kst() -> datetime:
    return datetime.now(KST).replace(microsecond=0)


def today_kst() -> str:
    return now_kst().date().isoformat()


def read_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, data, *, one_line_list_key: str | None = None) -> None:
    """UTF-8, LF, 결정적 출력.

    one_line_list_key 가 주어지면 그 최상위 배열의 원소를 한 줄에 하나씩 써서
    파일 크기를 줄이면서도 git diff 가 가게 단위로 보이게 한다.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    if one_line_list_key is None:
        text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    else:
        head = {k: v for k, v in data.items() if k != one_line_list_key}
        lines = ["{"]
        for k, v in head.items():
            lines.append(f"  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)},")
        items = data[one_line_list_key]
        lines.append(f"  {json.dumps(one_line_list_key)}: [")
        for i, item in enumerate(items):
            sep = "," if i < len(items) - 1 else ""
            lines.append("    " + json.dumps(item, ensure_ascii=False, separators=(",", ":")) + sep)
        lines.append("  ]")
        lines.append("}")
        text = "\n".join(lines) + "\n"
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text)
