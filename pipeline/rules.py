"""업소 포함 여부·카테고리·프랜차이즈 판정 규칙.

규칙은 상호(사업장명)와 업태구분명만 본다. 오분류는 data/curated 로 바로잡는다
(curated 의 category 가 base 값을 덮어쓰고, closed: true 로 목록에서 뺄 수 있다).
"""
from __future__ import annotations

import re

# 어느 인허가 종류든 이 단어가 상호에 있으면 제외 (빵·디저트 가게가 아님)
HARD_NEGATIVE = re.compile(
    r"떡볶|떡복|떡뽁|떡갈비|피자|치킨|김밥|분식|버거|맥도날드|롯데리아|만두|라면|"
    r"스터디|할인|무인\s*아이스|편의점|지에스25|gs25|씨유|세븐일레븐|이마트24|미니스톱|"
    r"스넥|스낵|호프|주점|노래",
    re.IGNORECASE,
)
# 업태구분명 자체가 대상이 아닌 경우
NEGATIVE_BIZ_TYPES = {"푸드트럭", "편의점", "키즈카페"}
# 휴게음식점에서는 길거리 간식·휴게소 매대로 보고 제외 (제과점영업 인허가면 그대로 둔다)
REST_CAFE_NEGATIVE = re.compile(r"호떡|붕어빵|국화빵|계란빵|땅콩빵|십원빵|찐빵|풀빵|어묵|휴게소|탕후루")

# 상호만으로 커피 중심 가게로 보이는 경우 (긍정 키워드가 없을 때만 적용)
COFFEE_NAME = re.compile(
    r"커피|coffee|에스프레소|espresso|로스팅|로스터|이디야|스타벅스|메가엠지씨|메가커피|컴포즈|빽다방|"
    r"투썸|할리스|파스쿠찌|탐앤탐스|엔제리너스|폴바셋|커피빈",
    re.IGNORECASE,
)
# 휴게음식점을 업태만으로 포함할 때 걸러낼 매장·마트 상호
RETAIL_NAME = re.compile(r"마트(?!리)|마켓")

FROZEN = re.compile(
    r"도넛|도너츠|도너스|donut|doughnut|아이스크림|ice ?cream|젤라또|젤라토|gelato|빙수|빙과|설빙|"
    r"배스킨|베스킨|라빈스|크리스피크림|던킨|요거트|요아정|하겐다즈|나뚜루|스쿱스",
    re.IGNORECASE,
)
# 빵집이 분명한 단어 — 디저트 단어와 함께 있으면 빵집으로 본다
BAKERY_STRONG = re.compile(
    r"베이커리|bakery|베이커스|베이크|bake|베이킹|baking|제과|빵|브레드|bread|블랑제|boulangerie|브로트|"
    r"베이글|bagel|오븐|oven|크루아상|크로와상|크라상|croissant|소금빵|식빵|바게트|깜빠뉴|꽈배기|"
    r"파리바게|파리바게트|뚜레쥬르",
    re.IGNORECASE,
)
DESSERT = re.compile(
    r"케이크|케익|케잌|케키|cake|마카롱|macaron|쿠키|cookie|디저트|dessert|파티세리|파티스리|patisserie|"
    r"빠띠시|파티시에|타르트|\btart|떡|와플|크로플|크레페|crepe|푸딩|마들렌|휘낭시에|까눌레|스콘|"
    r"초콜릿|쇼콜라|chocolat|구움|양과자|화과자|호두과자|츄러스|츄로|약과|젤리|부띠끄",
    re.IGNORECASE,
)
# 휴게음식점에서 포함 근거로만 쓰는 약한 단어 (카테고리는 bakery)
BAKERY_WEAK = re.compile(r"과자점|파이(?:\s|$|\(|집|룸|&)", re.IGNORECASE)

# 업태구분명으로 포함하는 휴게음식점 업태 → 기본 카테고리
INCLUDED_BIZ_TYPES = {"아이스크림": "frozen", "떡카페": "dessert", "과자점": "bakery"}

FRANCHISES = (
    ("파리바게", True),
    ("파리바게트", True),
    ("뚜레쥬르", True),
    ("던킨", True),
    ("배스킨", True),
    ("베스킨", True),
    ("설빙", True),
    ("크리스피크림", True),
    ("요거트아이스크림의정석", True),
    ("요아정", True),
    ("디저트39", True),
    ("와플대학", True),
    ("스쿱스젤라또", True),
    ("백미당", True),
    ("노티드", True),
    ("브레댄코", True),
    ("몽블랑제", True),
    ("신세계푸드블랑제리", True),
    ("블랑제리대전터미널점", True),
    ("코스트코", True),
    ("트레이더스베이커리", True),
    ("성심당", False),
    ("케익부띠끄롯데대전점", False),  # 성심당 케익부띠끄 롯데점
    ("옛맛솜씨", False),  # 성심당 옛맛솜씨
)


def _compact(name: str) -> str:
    return re.sub(r"\s+", "", name).lower()


def franchise_of(name: str) -> bool | None:
    n = _compact(name)
    for key, value in FRANCHISES:
        if key.lower() in n:
            return value
    return None


def _category_from_name(name: str) -> str | None:
    if FROZEN.search(name):
        return "frozen"
    if BAKERY_STRONG.search(name):
        return "bakery"
    if DESSERT.search(name):
        return "dessert"
    return None


def classify(kind: str, name: str, biz_type: str) -> tuple[str | None, str]:
    """(category | None, reason). category 가 None 이면 제외."""
    # '빵빵'(의성어) 같은 상호가 '빵'에 걸리지 않게 한다
    probe = name.replace("빵빵", "")
    if biz_type in NEGATIVE_BIZ_TYPES:
        return None, f"제외 업태:{biz_type}"
    if HARD_NEGATIVE.search(probe):
        return None, "제외 단어"
    by_name = _category_from_name(probe)

    if kind == "제과점영업":
        if by_name:
            return by_name, "제과점+상호"
        if COFFEE_NAME.search(probe):
            return None, "제과점이지만 커피 중심 상호"
        return "bakery", "제과점 기본"

    # 휴게음식점: 상호나 업태가 빵·디저트·아이스크림을 분명히 가리킬 때만
    if REST_CAFE_NEGATIVE.search(probe):
        return None, "휴게 길거리간식·휴게소"
    if by_name:
        return by_name, "휴게+상호"
    if biz_type in INCLUDED_BIZ_TYPES:
        if COFFEE_NAME.search(probe) or RETAIL_NAME.search(probe):
            return None, f"업태 {biz_type}이지만 커피·마트 상호"
        return INCLUDED_BIZ_TYPES[biz_type], f"휴게+업태:{biz_type}"
    if BAKERY_WEAK.search(probe):
        return "bakery", "휴게+상호(약)"
    return None, "휴게 대상 아님"
