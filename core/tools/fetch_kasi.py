"""한국천문연구원(KASI) 24절기·음양력 데이터를 받아 골든 테스트 fixture로 저장한다 (spec 13.2).

사용:
    set -a && . ./.env && set +a   # KASI_SERVICE_KEY (저장소에 넣지 않는다)
    uv run python tools/fetch_kasi.py --terms-years 2000-2028 --lunar-years 1900-2050
    uv run python tools/fetch_kasi.py --years 2000-2028     # 두 범위를 한 번에 지정

이미 fixture에 있는 연도·날짜는 다시 받지 않는다. 중간에 실패하면 같은 명령으로 이어 받는다.
연도(절기)·월(음력)마다 fixture를 저장한다.

API (공공데이터포털, 2026-10-10 확인)
* 절기: SpcdeInfoService/get24DivisionsInfo?solYear=YYYY&numOfRows=30&_type=json → 1년 24건.
  - dateName: 한글 절기명(예 "입춘")
  - kst: 입절 시각 KST, "HHMM" 뒤에 공백 패딩(예 "1727      "). 분 단위.
  - locdate: KST 날짜, yyyymmdd 정수(예 20240204)
  - sunLongitude: 태양 황경, 정수(입춘 = 315). 2000년 등 일부 연도 응답에는 없어서 fixture에 담지 않는다.
  - 제공 범위: 2000~2028년. 그 밖의 연도는 totalCount 0.
* 음양력(양력 → 음력): LrsrCldInfoService/getLunCalInfo?solYear=YYYY&solMonth=MM&solDay=DD&_type=json
  - lunYear, lunMonth, lunDay: 음력 연·월·일. 문자열("01")과 정수(18)가 섞여 온다.
  - lunLeapmonth: "윤"(윤달) 또는 "평"
  - solYear, solMonth, solDay: 요청한 양력 날짜
  - 제공 범위: 1900~2050-12-31. 2051년 이후는 0건.
* 공통: response.body.items.item은 1건이면 객체, 여러 건이면 배열이다. 0건이면 items가 빈 문자열일 수 있다.

fixture 형식
* tests/golden/fixtures/kasi_solar_terms.json: {"terms": [{"date": "YYYY-MM-DD", "name": 한글 절기명,
  "kst": "HH:MM"}]}
* tests/golden/fixtures/kasi_lunar.json: {"dates": [{"solar_date": "YYYY-MM-DD", "lunar_year": int,
  "lunar_month": int, "lunar_day": int, "is_leap_month": bool}]} — 매월 1일·15일, 1900-02-01부터
  (그 전 날짜의 음력은 엔진 지원 범위인 음력 1900년 밖이다).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from datetime import date
from pathlib import Path

BASE_URL = "https://apis.data.go.kr/B090041/openapi/service"
SOLAR_TERMS_URL = f"{BASE_URL}/SpcdeInfoService/get24DivisionsInfo"
LUNAR_URL = f"{BASE_URL}/LrsrCldInfoService/getLunCalInfo"
FIXTURES = Path(__file__).resolve().parents[1] / "tests" / "golden" / "fixtures"
SOLAR_TERMS_PATH = FIXTURES / "kasi_solar_terms.json"
LUNAR_PATH = FIXTURES / "kasi_lunar.json"
LUNAR_FIRST_DATE = date(1900, 2, 1)
LUNAR_DAYS_OF_MONTH = (1, 15)
LEAP_MONTH_MARK = "윤"
REQUEST_INTERVAL_SECONDS = 0.07
REQUEST_TIMEOUT_SECONDS = 20
MAX_ATTEMPTS = 4  # 첫 시도 + 재시도 3회
BACKOFF_BASE_SECONDS = 1.0
SUCCESS_CODE = "00"

Record = dict[str, object]


class KasiError(RuntimeError):
    """KASI 응답이 정상이 아니다."""


def main() -> int:
    args = _parse_args()
    service_key = os.environ.get("KASI_SERVICE_KEY")
    if not service_key:
        print("KASI_SERVICE_KEY 환경 변수가 필요합니다.", file=sys.stderr)
        return 1
    terms_years = args.terms_years or args.years
    lunar_years = args.lunar_years or args.years
    if terms_years is None and lunar_years is None:
        print("--years, --terms-years, --lunar-years 중 하나가 필요합니다.", file=sys.stderr)
        return 1
    if terms_years is not None:
        fetch_solar_terms(service_key, terms_years)
    if lunar_years is not None:
        fetch_lunar(service_key, lunar_years)
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--years", type=_year_range, help="절기·음력 공통 연도 범위, 예 2000-2028")
    parser.add_argument("--terms-years", type=_year_range, help="절기 연도 범위 (--years보다 우선)")
    parser.add_argument("--lunar-years", type=_year_range, help="음력 연도 범위 (--years보다 우선)")
    return parser.parse_args()


def _year_range(text: str) -> range:
    first, _, last = text.partition("-")
    try:
        first_year = int(first)
        last_year = int(last or first)
    except ValueError as error:
        raise argparse.ArgumentTypeError(f"연도 범위 형식이 아닙니다: {text!r}") from error
    if first_year > last_year:
        raise argparse.ArgumentTypeError(f"시작 연도가 끝 연도보다 큽니다: {text!r}")
    return range(first_year, last_year + 1)


# --- 절기 ---


def fetch_solar_terms(service_key: str, years: range) -> None:
    terms = _read_records(SOLAR_TERMS_PATH, "terms")
    done_years = {str(term["date"])[:4] for term in terms}
    for year in years:
        if str(year) in done_years:
            continue
        items = _fetch_items(service_key, SOLAR_TERMS_URL, {"solYear": str(year), "numOfRows": "30"})
        if not items:
            print(f"절기 {year}: KASI 미제공 (0건)", flush=True)
            continue
        terms.extend(_solar_term_record(item) for item in items)
        terms.sort(key=lambda term: (str(term["date"]), str(term["kst"])))
        _write_records(SOLAR_TERMS_PATH, "terms", terms)
        print(f"절기 {year}: {len(items)}건", flush=True)


def _solar_term_record(item: Record) -> Record:
    locdate = str(_as_int(item["locdate"]))
    kst = str(item["kst"]).strip()
    if len(locdate) != 8 or len(kst) != 4 or not kst.isdigit():
        raise KasiError(f"절기 항목 형식이 예상과 다릅니다: locdate={locdate!r}, kst={kst!r}")
    return {
        "date": f"{locdate[:4]}-{locdate[4:6]}-{locdate[6:]}",
        "name": str(item["dateName"]).strip(),
        "kst": f"{kst[:2]}:{kst[2:]}",
    }


# --- 음양력 ---


def fetch_lunar(service_key: str, years: range) -> None:
    records = _read_records(LUNAR_PATH, "dates")
    done_dates = {str(record["solar_date"]) for record in records}
    for year in years:
        for month in range(1, 13):
            fetched = 0
            for day in LUNAR_DAYS_OF_MONTH:
                solar_date = date(year, month, day)
                if solar_date < LUNAR_FIRST_DATE or solar_date.isoformat() in done_dates:
                    continue
                params = {"solYear": str(year), "solMonth": f"{month:02d}", "solDay": f"{day:02d}"}
                items = _fetch_items(service_key, LUNAR_URL, params)
                if not items:
                    print(f"음력 {solar_date}: KASI 미제공 (0건)", flush=True)
                    continue
                records.append(_lunar_record(solar_date, items[0]))
                done_dates.add(solar_date.isoformat())
                fetched += 1
            if fetched:
                records.sort(key=lambda record: str(record["solar_date"]))
                _write_records(LUNAR_PATH, "dates", records)
        print(f"음력 {year}: 누적 {len(records)}건", flush=True)


def _lunar_record(solar_date: date, item: Record) -> Record:
    echoed = date(_as_int(item["solYear"]), _as_int(item["solMonth"]), _as_int(item["solDay"]))
    if echoed != solar_date:
        raise KasiError(f"요청한 날짜와 응답 날짜가 다릅니다: {solar_date} != {echoed}")
    return {
        "solar_date": solar_date.isoformat(),
        "lunar_year": _as_int(item["lunYear"]),
        "lunar_month": _as_int(item["lunMonth"]),
        "lunar_day": _as_int(item["lunDay"]),
        "is_leap_month": str(item["lunLeapmonth"]).strip() == LEAP_MONTH_MARK,
    }


# --- HTTP·JSON ---


def _fetch_items(service_key: str, url: str, params: dict[str, str]) -> list[Record]:
    query = urllib.parse.urlencode({**params, "_type": "json"})
    # 서비스 키는 이미 인코딩된 형태로 발급되므로 그대로 붙인다. 오류 메시지에 URL을 넣지 않는다(키 노출 방지).
    request_url = f"{url}?serviceKey={service_key}&{query}"
    payload = _with_retry(lambda: _get_json(request_url), describe=f"{url.rsplit('/', 1)[-1]} {params}")
    time.sleep(REQUEST_INTERVAL_SECONDS)
    return _items_of(payload)


def _get_json(request_url: str) -> object:
    with urllib.request.urlopen(request_url, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        body: bytes = response.read()
    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        # 키 오류 등은 XML로 돌아온다. 본문 앞부분만 남긴다.
        raise KasiError(f"JSON이 아닌 응답: {body[:200]!r}") from error


def _with_retry(fetch: Callable[[], object], describe: str) -> object:
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            payload = fetch()
            _check_header(payload)
            return payload
        except (urllib.error.URLError, TimeoutError, KasiError) as error:
            if attempt == MAX_ATTEMPTS:
                raise KasiError(f"{describe}: {MAX_ATTEMPTS}회 실패 ({_describe_error(error)})") from None
            wait = BACKOFF_BASE_SECONDS * 2 ** (attempt - 1)
            print(f"{describe}: {_describe_error(error)}, {wait:.0f}초 뒤 재시도", file=sys.stderr)
            time.sleep(wait)
    raise AssertionError("도달할 수 없음")


def _describe_error(error: Exception) -> str:
    if isinstance(error, urllib.error.HTTPError):
        return f"HTTP {error.code}"
    if isinstance(error, urllib.error.URLError):
        return f"연결 오류 {error.reason}"
    return str(error)


def _check_header(payload: object) -> None:
    header = _get_dict(_get_dict(payload, "response"), "header")
    code = str(header.get("resultCode"))
    if code != SUCCESS_CODE:
        raise KasiError(f"resultCode {code}: {header.get('resultMsg')}")


def _items_of(payload: object) -> list[Record]:
    body = _get_dict(_get_dict(payload, "response"), "body")
    if _as_int(body.get("totalCount", 0)) == 0:
        return []
    item = _get_dict(body, "items").get("item")
    candidates = item if isinstance(item, list) else [item]
    records: list[Record] = []
    for candidate in candidates:
        if not isinstance(candidate, dict):
            raise KasiError(f"item이 객체가 아닙니다: {candidate!r}")
        records.append({str(key): value for key, value in candidate.items()})
    return records


def _get_dict(container: object, key: str) -> Record:
    if not isinstance(container, dict):
        raise KasiError(f"{key}를 찾을 객체가 아닙니다: {container!r}")
    value = container.get(key)
    if not isinstance(value, dict):
        raise KasiError(f"{key}가 객체가 아닙니다: {value!r}")
    return {str(inner_key): inner_value for inner_key, inner_value in value.items()}


def _as_int(value: object) -> int:
    """ "01"·18처럼 섞여 오는 숫자 필드를 int로 정규화한다."""
    if isinstance(value, bool):
        raise KasiError(f"숫자 필드가 bool입니다: {value!r}")
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.strip().isdigit():
        return int(value.strip())
    raise KasiError(f"숫자 필드 형식이 아닙니다: {value!r}")


# --- fixture 파일 ---


def _read_records(path: Path, key: str) -> list[Record]:
    if not path.exists():
        return []
    data: object = json.loads(path.read_text(encoding="utf-8"))
    records = data.get(key) if isinstance(data, dict) else None
    if not isinstance(records, list):
        raise KasiError(f"{path.name}의 {key} 형식이 잘못되었습니다.")
    result: list[Record] = []
    for record in records:
        if not isinstance(record, dict):
            raise KasiError(f"{path.name}의 항목이 객체가 아닙니다: {record!r}")
        result.append({str(field): value for field, value in record.items()})
    return result


def _write_records(path: Path, key: str, records: list[Record]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps({key: records}, ensure_ascii=False, indent=1)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(text + "\n", encoding="utf-8")
    temporary.replace(path)


if __name__ == "__main__":
    sys.exit(main())
