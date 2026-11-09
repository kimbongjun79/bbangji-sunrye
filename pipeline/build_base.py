"""data/raw/*.csv → data/base/stores_base.json

- 업소 포함 여부·카테고리 판정(rules.py)
- 좌표 변환: Bessel 중부원점TM(EPSG:5174) → WGS84
- 같은 좌표에 같은 상호(끝의 번호만 다름)로 여러 인허가가 있는 경우 한 가게로 묶음
  (예: '성심당 롯데대전점1'~'6'). 묶여 사라진 id 는 aliases 로 남겨 curated 의 id 매칭에 쓴다.
"""
from __future__ import annotations

import csv
import re
from collections import Counter, defaultdict

from pyproj import Transformer

from common import (
    BASE_PATH,
    DISTRICTS,
    LICENSE_NOTE,
    ORG_DISTRICT,
    RAW_DIR,
    SOURCES,
    read_json,
    write_json,
)
from rules import classify, franchise_of

# 데이터셋 설명: "좌표계 : 보정계수 안들어간 Bessel 중부원점TM(EPSG:5174)"
TO_WGS84 = Transformer.from_crs("EPSG:5174", "EPSG:4326", always_xy=True)
# 대전광역시 경계 바깥으로 변환되면 좌표 오류로 본다
LAT_RANGE = (36.18, 36.50)
LNG_RANGE = (127.24, 127.56)
DISTRICT_RE = re.compile(r"대전광역시\s*(" + "|".join(DISTRICTS) + r")")


def to_wgs84(x: str, y: str) -> tuple[float, float] | None:
    try:
        fx, fy = float(x), float(y)
    except ValueError:
        return None
    if fx == 0 or fy == 0:
        return None
    lng, lat = TO_WGS84.transform(fx, fy)
    return round(lat, 6), round(lng, 6)


def format_phone(raw: str) -> str | None:
    """지역번호·대표번호만 남긴다. 휴대전화(01X)는 개인 번호일 수 있어 싣지 않는다."""
    d = re.sub(r"\D", "", raw)
    if not d or d.startswith("01"):
        return None
    if d.startswith("02") and len(d) in (9, 10):
        return f"02-{d[2:-4]}-{d[-4:]}"
    if re.match(r"0[3-6]\d|070|050\d?", d) and len(d) in (10, 11, 12):
        head = 4 if d.startswith("050") and len(d) == 12 else 3
        return f"{d[:head]}-{d[head:-4]}-{d[-4:]}"
    if re.match(r"1[5-8]\d\d", d) and len(d) == 8:
        return f"{d[:4]}-{d[4:]}"
    if len(d) in (7, 8):  # 지역번호 없이 적힌 대전 번호
        return f"042-{d[:-4]}-{d[-4:]}"
    return None


def district_of(row: dict) -> str | None:
    for addr in (row["roadAddress"], row["jibunAddress"]):
        m = DISTRICT_RE.search(addr)
        if m:
            return m.group(1)
    return ORG_DISTRICT.get(row["orgCode"])


def name_stem(name: str) -> str:
    """끝의 지점 번호·괄호 번호를 뗀 비교용 상호."""
    s = re.sub(r"\s+", "", name)
    s = re.sub(r"(\(\d+\)|\d+호?|\.)+$", "", s)
    return s.lower()


def display_name(name: str) -> str:
    return re.sub(r"\s*(\(\d+\)|\d+호?|\.)+$", "", name).strip() or name


def load_raw() -> list[dict]:
    rows = []
    for src in SOURCES.values():
        with (RAW_DIR / f"{src['slug']}.csv").open(encoding="utf-8", newline="") as f:
            rows.extend(csv.DictReader(f))
    return rows


def main() -> None:
    meta = read_json(RAW_DIR / "meta.json")
    checked_at = meta["fetchedAt"][:10]
    rows = load_raw()

    reasons: Counter = Counter()
    stats = defaultdict(Counter)  # kind → counter
    review_excluded = []  # 제과점영업인데 빠진 업소 (사람이 확인할 목록)
    no_coords = []
    candidates = []
    for r in rows:
        kind = r["kind"]
        category, reason = classify(kind, r["name"], r["bizType"])
        reasons[f"{kind} / {reason}"] += 1
        if category is None:
            stats[kind]["excluded"] += 1
            if kind == "제과점영업":
                review_excluded.append({"id": f"lic-{r['mgtNo']}", "name": r["name"], "reason": reason})
            continue
        coords = to_wgs84(r["x"], r["y"])
        district = district_of(r)
        if coords is None or not (LAT_RANGE[0] <= coords[0] <= LAT_RANGE[1] and LNG_RANGE[0] <= coords[1] <= LNG_RANGE[1]):
            stats[kind]["noCoords"] += 1
            no_coords.append({"id": f"lic-{r['mgtNo']}", "name": r["name"], "address": r["roadAddress"] or r["jibunAddress"],
                              "x": r["x"], "y": r["y"]})
            continue
        if district is None:
            stats[kind]["noDistrict"] += 1
            no_coords.append({"id": f"lic-{r['mgtNo']}", "name": r["name"], "address": r["roadAddress"] or r["jibunAddress"],
                              "x": r["x"], "y": r["y"], "note": "구 판별 불가"})
            continue
        stats[kind]["included"] += 1
        candidates.append((r, category, coords, district))

    # 같은 좌표 + 같은 상호 줄기 → 한 가게
    groups: dict[tuple, list] = defaultdict(list)
    for item in candidates:
        r, _, coords, _ = item
        groups[(coords, name_stem(r["name"]))].append(item)

    stores = []
    aliases = {}
    for (_, _), items in groups.items():
        items.sort(key=lambda it: (it[0]["licensedAt"], it[0]["mgtNo"]))
        r, category, (lat, lng), district = items[0]
        store_id = f"lic-{r['mgtNo']}"
        name = r["name"] if len(items) == 1 else display_name(r["name"])
        for other in items[1:]:
            aliases[f"lic-{other[0]['mgtNo']}"] = store_id
        phone = next((p for p in (format_phone(it[0]["phone"]) for it in items) if p), None)
        stores.append({
            "id": store_id,
            "name": name,
            "category": category,
            "franchise": franchise_of(r["name"]),
            "district": district,
            "address": r["roadAddress"] or r["jibunAddress"],
            "lat": lat,
            "lng": lng,
            "phone": phone,
            "instagram": None,
            "website": None,
            "hours": None,
            "holidayNote": None,
            "products": [],
            "photos": [],
            "sources": [],
            "verifiedAt": None,
            "license": {
                "mgtNo": r["mgtNo"],
                "kind": r["kind"],
                "licensedAt": r["licensedAt"] or None,
                "status": r["status"],
                "checkedAt": checked_at,
            },
        })
    stores.sort(key=lambda s: s["id"])

    base = {
        "generatedFrom": {
            "fetchedAt": meta["fetchedAt"],
            "license": LICENSE_NOTE,
            "sources": {k: {"dataset": v["dataset"], "download": v["download"], "sourceLastUpdated": v["sourceLastUpdated"]}
                        for k, v in meta["sources"].items()},
        },
        "stats": {
            "openLicenses": {k: v["open"] for k, v in meta["sources"].items()},
            "byKind": {k: dict(sorted(v.items())) for k, v in sorted(stats.items())},
            "mergedDuplicates": len(aliases),
            "storeCount": len(stores),
            "categories": dict(sorted(Counter(s["category"] for s in stores).items())),
            "reasons": dict(sorted(reasons.items())),
        },
        "review": {
            "excludedBakeryLicenses": sorted(review_excluded, key=lambda e: e["id"]),
            "noCoords": sorted(no_coords, key=lambda e: e["id"]),
        },
        "aliases": dict(sorted(aliases.items())),
        "stores": stores,
    }
    write_json(BASE_PATH, base, one_line_list_key="stores")
    print(f"[build] 가게 {len(stores)}곳 (중복 묶음 {len(aliases)}건, 좌표·구 없음 {len(no_coords)}건) "
          f"카테고리 {base['stats']['categories']}")


if __name__ == "__main__":
    main()
