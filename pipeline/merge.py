"""data/base/stores_base.json + data/curated/*.json → data/stores.json, pipeline/out/report.md

병합 규칙 (docs/DATA_SCHEMA.md):
- curated 항목은 id(있으면, 묶인 인허가의 id 도 aliases 로 인정) → 없으면 match:{name,address} 정규화 비교로 base 와 맞춘다.
- curated 값이 base 값을 덮어쓴다. null 은 덮어쓰지 않는다. closed: true 면 목록에서 뺀다.
- 매칭되지 않은 항목은 lat,lng,category,address,district 가 모두 있어야 단독 가게로 추가한다.
- 스키마 검증에 실패한 curated 항목은 적용하지 않고 보고서에 남긴다.
- 가게 목록이 이전 stores.json 과 같으면(license.checkedAt 제외) 파일을 다시 쓰지 않는다.
"""
from __future__ import annotations

import copy
import json
import re
import sys
from collections import Counter
from datetime import timedelta

from common import (
    BASE_PATH,
    CURATED_DIR,
    DISTRICTS,
    OUT_DIR,
    REGION,
    STORES_PATH,
    now_kst,
    read_json,
    write_json,
)

SCHEMA_VERSION = 1
CATEGORIES = ("bakery", "dessert", "frozen")
CATEGORY_KO = {"bakery": "빵집·베이커리", "dessert": "디저트", "frozen": "도넛·아이스크림·빙수"}
STORE_FIELDS = (
    "id", "name", "category", "franchise", "district", "address", "lat", "lng", "phone", "instagram",
    "website", "hours", "holidayNote", "products", "photos", "sources", "verifiedAt", "license",
)
CURATED_CONTROL = {"id", "match", "closed"}
STANDALONE_REQUIRED = ("lat", "lng", "category", "address", "district")
DAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
STALE_DAYS = 90
LIST_LIMIT = 150
COVERAGE_NOTE = "인허가 데이터 기준 영업 중 업소. 누락·폐업 반영 지연 가능"

TIME_RE = re.compile(r"^([01]\d|2[0-4]):[0-5]\d$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


# ---------------------------------------------------------------- 정규화·매칭

def norm_name(name: str) -> str:
    s = name.lower()
    s = re.sub(r"\(주\)|㈜|주식회사", "", s)
    return re.sub(r"[^0-9a-z가-힣]", "", s)


def addr_core(address: str) -> str:
    """'대전광역시 중구 대종로480번길 15, 1층 (은행동)' → '중구대종로480번길15'"""
    s = re.split(r"[,(]", address, maxsplit=1)[0]
    s = re.sub(r"^\s*(대전광역시|대전시|대전)\s*", "", s)
    return re.sub(r"\s+", "", s)


def names_related(a: str, b: str) -> bool:
    a, b = norm_name(a), norm_name(b)
    if not a or not b:
        return False
    if a in b or b in a:
        return True
    # 공통 부분 문자열이 3자 이상이면 같은 가게로 본다 (예: '디씨씨성심당' ↔ '성심당dcc점')
    short, long_ = sorted((a, b), key=len)
    return any(short[i:i + 3] in long_ for i in range(len(short) - 2))


class Matcher:
    def __init__(self, stores: dict[str, dict], aliases: dict[str, str]):
        self.stores = stores
        self.aliases = aliases
        self.by_addr: dict[str, list[str]] = {}
        self.by_name: dict[str, list[str]] = {}
        for sid, s in stores.items():
            self.by_addr.setdefault(addr_core(s["address"]), []).append(sid)
            self.by_name.setdefault(norm_name(s["name"]), []).append(sid)

    def resolve_id(self, sid: str | None) -> str | None:
        if not sid:
            return None
        sid = self.aliases.get(sid, sid)
        return sid if sid in self.stores else None

    def match(self, name: str | None, address: str | None) -> tuple[str | None, str]:
        if address:
            cands = [sid for sid in self.by_addr.get(addr_core(address), []) if sid in self.stores]
            if name:
                exact = [sid for sid in cands if norm_name(self.stores[sid]["name"]) == norm_name(name)]
                if len(exact) == 1:
                    return exact[0], "이름+주소"
                related = [sid for sid in cands if names_related(self.stores[sid]["name"], name)]
                if len(related) == 1:
                    return related[0], "주소+유사 이름"
                if len(related) > 1:
                    return None, f"같은 주소에 후보 {len(related)}곳"
            elif len(cands) == 1:
                return cands[0], "주소"
        if name:
            same = [sid for sid in self.by_name.get(norm_name(name), []) if sid in self.stores]
            if len(same) == 1:
                return same[0], "이름" if not address else "이름(주소 불일치)"
            if len(same) > 1:
                return None, f"같은 이름 후보 {len(same)}곳"
        return None, "후보 없음"


# ---------------------------------------------------------------- 검증

def _is_url(v) -> bool:
    return isinstance(v, str) and v.startswith(("https://", "http://"))


def _opt_str(v) -> bool:
    return v is None or (isinstance(v, str) and v.strip() != "")


def validate_store(s: dict) -> list[str]:
    e = []
    for f in STORE_FIELDS:
        if f not in s:
            e.append(f"{f} 없음")
    if e:
        return e
    if not isinstance(s["id"], str) or not re.match(r"^(lic|cur)-.+", s["id"]):
        e.append("id 형식")
    if not isinstance(s["name"], str) or not s["name"].strip():
        e.append("name")
    if s["category"] not in CATEGORIES:
        e.append(f"category={s['category']!r}")
    if s["franchise"] not in (True, False, None):
        e.append("franchise")
    if s["district"] not in DISTRICTS:
        e.append(f"district={s['district']!r}")
    if not isinstance(s["address"], str) or not s["address"].strip():
        e.append("address")
    for f, lo, hi in (("lat", 36.0, 36.7), ("lng", 127.1, 127.8)):
        v = s[f]
        if isinstance(v, bool) or not isinstance(v, (int, float)) or not lo <= v <= hi:
            e.append(f"{f}={v!r} (대전 범위 밖)")
    for f in ("phone", "holidayNote"):
        if not _opt_str(s[f]):
            e.append(f)
    for f in ("instagram", "website"):
        if s[f] is not None and not _is_url(s[f]):
            e.append(f"{f} URL 아님")
    h = s["hours"]
    if h is not None:
        if not isinstance(h, dict) or set(h) - set(DAYS):
            e.append("hours 요일 키")
        else:
            for day, v in h.items():
                if v is None:
                    continue
                if not isinstance(v, dict) or not TIME_RE.match(str(v.get("open", ""))) or not TIME_RE.match(str(v.get("close", ""))):
                    e.append(f"hours.{day} open/close")
                    continue
                if set(v) - {"open", "close", "breaks", "lastOrder"}:
                    e.append(f"hours.{day} 알 수 없는 키")
                if "lastOrder" in v and not TIME_RE.match(str(v["lastOrder"])):
                    e.append(f"hours.{day}.lastOrder")
                br = v.get("breaks", [])
                if not isinstance(br, list) or not all(
                    isinstance(b, list) and len(b) == 2 and all(TIME_RE.match(str(t)) for t in b) for b in br
                ):
                    e.append(f"hours.{day}.breaks")
    if not isinstance(s["products"], list) or not all(
        isinstance(p, dict) and isinstance(p.get("name"), str) and p["name"].strip()
        and (p.get("price") is None or (isinstance(p.get("price"), int) and not isinstance(p.get("price"), bool)))
        and _opt_str(p.get("note"))
        for p in s["products"]
    ):
        e.append("products")
    if not isinstance(s["photos"], list) or not all(
        isinstance(p, dict) and _is_url(p.get("url")) and isinstance(p.get("credit"), str) for p in s["photos"]
    ):
        e.append("photos")
    if not isinstance(s["sources"], list) or not all(
        isinstance(p, dict) and _is_url(p.get("url")) and isinstance(p.get("title"), str)
        and DATE_RE.match(str(p.get("checkedAt", "")))
        for p in s["sources"]
    ):
        e.append("sources (url, title, checkedAt 필요)")
    if s["verifiedAt"] is not None and not DATE_RE.match(str(s["verifiedAt"])):
        e.append("verifiedAt")
    lic = s["license"]
    if lic is not None and (
        not isinstance(lic, dict)
        or set(lic) != {"mgtNo", "kind", "licensedAt", "status", "checkedAt"}
        or lic["kind"] not in ("제과점영업", "휴게음식점")
    ):
        e.append("license")
    return e


# ---------------------------------------------------------------- 병합

def blank_store(sid: str) -> dict:
    return {
        "id": sid, "name": None, "category": None, "franchise": None, "district": None, "address": None,
        "lat": None, "lng": None, "phone": None, "instagram": None, "website": None, "hours": None,
        "holidayNote": None, "products": [], "photos": [], "sources": [], "verifiedAt": None, "license": None,
    }


def apply_fields(target: dict, entry: dict) -> list[str]:
    unknown = []
    for k, v in entry.items():
        if k in CURATED_CONTROL:
            continue
        if k not in STORE_FIELDS:
            unknown.append(k)
            continue
        if v is None:
            continue
        target[k] = v
    return unknown


def slug_id(entry: dict) -> str:
    base = norm_name(entry.get("name") or "") or "store"
    return f"cur-{base}-{addr_core(entry.get('address') or '')}"


def load_curated() -> tuple[list[tuple[str, int, dict]], list[str]]:
    entries, errors = [], []
    if not CURATED_DIR.exists():
        return entries, errors
    for path in sorted(CURATED_DIR.glob("*.json")):
        try:
            data = read_json(path)
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            errors.append(f"`{path.name}` 읽기 실패: {e}")
            continue
        if isinstance(data, dict) and isinstance(data.get("stores"), list):
            data = data["stores"]
        if not isinstance(data, list):
            errors.append(f"`{path.name}`: 최상위가 배열이 아님")
            continue
        for i, entry in enumerate(data):
            if isinstance(entry, dict):
                entries.append((path.name, i, entry))
            else:
                errors.append(f"`{path.name}`[{i}]: 객체가 아님")
    return entries, errors


def strip_volatile(stores: list[dict]) -> list[dict]:
    out = []
    for s in stores:
        s = dict(s)
        if isinstance(s.get("license"), dict):
            s["license"] = {k: v for k, v in s["license"].items() if k != "checkedAt"}
        out.append(s)
    return out


def main() -> int:
    today = now_kst()
    base = read_json(BASE_PATH)
    stores = {s["id"]: copy.deepcopy(s) for s in base["stores"]}
    base_errors = {sid: errs for sid, s in stores.items() if (errs := validate_store(s))}
    if base_errors:
        for sid, errs in list(base_errors.items())[:20]:
            print(f"[merge] base 검증 실패 {sid}: {errs}", file=sys.stderr)
        return 1

    matcher = Matcher(stores, base.get("aliases", {}))
    curated, load_errors = load_curated()
    log = {"applied": [], "closed": [], "standalone": [], "unmatched": [], "invalid": [], "unknownKeys": [],
           "noSources": [], "duplicate": []}
    touched: dict[str, str] = {}

    for fname, idx, entry in curated:
        where = f"{fname}[{idx}]"
        label = entry.get("name") or (entry.get("match") or {}).get("name") or entry.get("id") or "?"
        sid = matcher.resolve_id(entry.get("id"))
        how = "id" if sid else ""
        if sid is None:
            m = entry.get("match") or {}
            sid, how = matcher.match(m.get("name") or entry.get("name"), m.get("address") or entry.get("address"))
        if not entry.get("name") and not (entry.get("match") or {}).get("name") and sid in stores:
            label = stores[sid]["name"]

        if entry.get("closed") is True:
            if sid and sid in stores:
                del stores[sid]
                log["closed"].append(f"{label} (`{sid}`, {how}) — {where}")
            else:
                log["unmatched"].append(f"{label} — {where}: closed 항목이지만 기본 목록에 없음 ({how})")
            continue

        if sid is not None:
            if sid in touched:
                log["duplicate"].append(f"{label} (`{sid}`) — {where} 와 {touched[sid]}")
            candidate = copy.deepcopy(stores[sid])
            kind = "applied"
        else:
            missing = [f for f in STANDALONE_REQUIRED if entry.get(f) is None] + ([] if entry.get("name") else ["name"])
            if missing:
                log["unmatched"].append(f"{label} — {where}: {how}; 단독 추가 필드 부족 {missing}")
                continue
            new_id = entry.get("id") if isinstance(entry.get("id"), str) and entry["id"].startswith("cur-") else slug_id(entry)
            if new_id in stores:
                log["invalid"].append(f"{label} — {where}: 단독 추가 id `{new_id}` 가 이미 있음")
                continue
            sid, how = new_id, "단독"
            candidate = blank_store(sid)
            kind = "standalone"

        unknown = apply_fields(candidate, entry)
        if unknown:
            log["unknownKeys"].append(f"{label} — {where}: {unknown}")
        errs = validate_store(candidate)
        if errs:
            log["invalid"].append(f"{label} — {where}: {', '.join(errs)}")
            continue
        stores[sid] = candidate
        touched[sid] = where
        log[kind].append(f"{label} (`{sid}`, {how}) — {where}")
        detail = any(entry.get(k) not in (None, [], "") for k in ("hours", "holidayNote", "products", "phone", "instagram", "website"))
        if detail and not candidate["sources"]:
            log["noSources"].append(f"{label} (`{sid}`) — {where}")

    final = sorted(stores.values(), key=lambda s: s["id"])
    errors = {s["id"]: errs for s in final if (errs := validate_store(s))}
    if errors:
        for sid, errs in errors.items():
            print(f"[merge] 검증 실패 {sid}: {errs}", file=sys.stderr)
        return 1

    previous = read_json(STORES_PATH) if STORES_PATH.exists() else None
    prev_stores = previous["stores"] if previous else []
    changed = strip_volatile(prev_stores) != strip_volatile(final)
    if changed:
        doc = {
            "schemaVersion": SCHEMA_VERSION,
            "dataVersion": today.date().isoformat(),
            "generatedAt": today.isoformat(),
            "coverage": {
                "region": REGION,
                "storeCount": len(final),
                "curatedCount": sum(1 for s in final if s["verifiedAt"]),
                "note": COVERAGE_NOTE,
            },
            "stores": final,
        }
        write_json(STORES_PATH, doc, one_line_list_key="stores")

    write_report(today, base, final, prev_stores, previous, changed, log, load_errors)
    print(f"[merge] 가게 {len(final)}곳, curated 적용 {len(log['applied'])}·단독 {len(log['standalone'])}·"
          f"폐업 {len(log['closed'])}·미매칭 {len(log['unmatched'])}·검증실패 {len(log['invalid'])} — "
          f"{'stores.json 갱신' if changed else '변경 없음'}")
    return 0


# ---------------------------------------------------------------- 보고서

def _bullets(items: list[str], limit: int = LIST_LIMIT) -> list[str]:
    if not items:
        return ["- 없음"]
    out = [f"- {x}" for x in items[:limit]]
    if len(items) > limit:
        out.append(f"- … 외 {len(items) - limit}건")
    return out


def _store_line(s: dict) -> str:
    return f"{s['name']} · {CATEGORY_KO.get(s['category'], s['category'])} · {s['district']} · {s['address']} (`{s['id']}`)"


def write_report(today, base, final, prev_stores, previous, changed, log, load_errors) -> None:
    prev_by_id = {s["id"]: s for s in prev_stores}
    new_by_id = {s["id"]: s for s in final}
    added = [new_by_id[i] for i in sorted(set(new_by_id) - set(prev_by_id))]
    removed = [prev_by_id[i] for i in sorted(set(prev_by_id) - set(new_by_id))]
    modified = [i for i in sorted(set(new_by_id) & set(prev_by_id))
                if strip_volatile([new_by_id[i]]) != strip_volatile([prev_by_id[i]])]

    stale_before = (today.date() - timedelta(days=STALE_DAYS)).isoformat()
    stale = sorted((s for s in final if s["verifiedAt"] and s["verifiedAt"] < stale_before), key=lambda s: s["verifiedAt"])
    gen = base["generatedFrom"]
    st = base["stats"]

    L = [f"# 빵지순례 데이터 갱신 보고서 — {today.date().isoformat()}", ""]
    L.append(f"**결과: {'`data/stores.json` 변경 있음' if changed else '변경 없음 (stores.json 그대로)'}**")
    L.append("")
    L.append(f"- 가게 {len(final)}곳 (이전 {len(prev_stores) if previous else '파일 없음'}), "
             f"검수된 상세정보 {sum(1 for s in final if s['verifiedAt'])}곳")
    L.append(f"- 신규 {len(added)} · 제외 {len(removed)} · 내용 변경 {len(modified)}")
    L.append(f"- 원본: {gen['license']}")
    for kind, src in gen["sources"].items():
        L.append(f"  - {kind}: [{src['dataset']}]({src['dataset']}) — 원본 최종 갱신 {src['sourceLastUpdated']}, 수집 {gen['fetchedAt']}")
    L.append("")

    L.append("## 카테고리 × 구")
    L.append("")
    L.append("| 카테고리 | " + " | ".join(DISTRICTS) + " | 합계 |")
    L.append("|---|" + "---:|" * (len(DISTRICTS) + 1))
    grid = Counter((s["category"], s["district"]) for s in final)
    for c in CATEGORIES:
        row = [grid[(c, d)] for d in DISTRICTS]
        L.append(f"| {CATEGORY_KO[c]} | " + " | ".join(map(str, row)) + f" | {sum(row)} |")
    totals = [sum(grid[(c, d)] for c in CATEGORIES) for d in DISTRICTS]
    L.append("| 합계 | " + " | ".join(map(str, totals)) + f" | {sum(totals)} |")
    L.append("")

    L.append("## 인허가 처리")
    L.append("")
    for kind, n in st["openLicenses"].items():
        k = st["byKind"].get(kind, {})
        L.append(f"- {kind}: 영업 중 {n} → 포함 {k.get('included', 0)}, 규칙상 제외 {k.get('excluded', 0)}, "
                 f"좌표·구 없음으로 제외 {k.get('noCoords', 0) + k.get('noDistrict', 0)}")
    L.append(f"- 같은 좌표·같은 상호 인허가 묶음: {st['mergedDuplicates']}건")
    L.append("")
    L.append("<details><summary>판정 사유별 건수</summary>")
    L.append("")
    L.extend(f"- {k}: {v}" for k, v in st["reasons"].items())
    L.append("")
    L.append("</details>")
    L.append("")

    L.append(f"## 신규 가게 ({len(added)})")
    L.append("")
    L.extend(_bullets([_store_line(s) for s in added]))
    L.append("")
    L.append(f"## 목록에서 빠진 가게 ({len(removed)})")
    L.append("")
    L.extend(_bullets([_store_line(s) for s in removed]))
    L.append("")
    if modified:
        L.append(f"## 내용이 바뀐 가게 ({len(modified)})")
        L.append("")
        L.extend(_bullets([_store_line(new_by_id[i]) for i in modified]))
        L.append("")

    L.append("## curated 병합")
    L.append("")
    if load_errors:
        L.append("### ⚠ 파일 오류")
        L.extend(_bullets(load_errors))
        L.append("")
    sections = (
        ("검증 실패 (적용 안 함)", "invalid"),
        ("매칭 안 됨", "unmatched"),
        ("같은 가게에 여러 항목", "duplicate"),
        ("상세정보가 있는데 sources 없음", "noSources"),
        ("스키마에 없는 키 (무시됨)", "unknownKeys"),
        ("closed 로 제외", "closed"),
        ("단독 추가", "standalone"),
    )
    for title, key in sections:
        L.append(f"### {title} ({len(log[key])})")
        L.extend(_bullets(log[key]))
        L.append("")
    L.append(f"### 적용됨 ({len(log['applied'])})")
    L.extend(_bullets(log["applied"]))
    L.append("")
    L.append(f"### 재확인 필요: verifiedAt 이 {STALE_DAYS}일 넘음 ({stale_before} 이전) ({len(stale)})")
    L.extend(_bullets([f"{s['name']} — verifiedAt {s['verifiedAt']} (`{s['id']}`)" for s in stale]))
    L.append("")

    L.append("## 사람 확인용")
    L.append("")
    rv = base.get("review", {})
    L.append(f"### 제과점영업이지만 규칙상 뺀 업소 ({len(rv.get('excludedBakeryLicenses', []))})")
    L.extend(_bullets([f"{e['name']} — {e['reason']} (`{e['id']}`)" for e in rv.get("excludedBakeryLicenses", [])]))
    L.append("")
    L.append(f"### 좌표·구가 없어 뺀 업소 ({len(rv.get('noCoords', []))})")
    L.extend(_bullets([f"{e['name']} — {e['address']} (`{e['id']}`)" for e in rv.get("noCoords", [])]))
    L.append("")
    L.append("판정 규칙: `pipeline/rules.py`. 잘못 분류된 가게는 `data/curated/` 에 `category` 를 적거나 `closed: true` 로 바로잡는다.")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with (OUT_DIR / "report.md").open("w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")


if __name__ == "__main__":
    sys.exit(main())
