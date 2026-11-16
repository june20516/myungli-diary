"""스토어 스크린샷용 대역 fixture(`fixtures/store-<언어>`, `store-<언어>-unlocked`)를 로컬 server 응답으로 만듭니다(#1203, D133).

스크린샷 화면 안 글은 각 언어로 찍습니다(design 스토어 명세). server가 렌더하는 문장(오늘, 달력, 나의 사주, 근거)은
기존 fixture가 ko뿐이라, 데모 프로필(member와 같은 출생 정보)로 로컬 server에 실제로 물어 세 언어 응답을 받습니다.
server 렌더 그대로라 언어마다 같은 날, 같은 판정입니다.

`tool/store_fixtures.sh`가 로컬 server(staging 빌드 태그, 테스트 로그인)를 띄운 뒤 부릅니다. 직접 부를 때는
STORE_API(예 http://127.0.0.1:47290)와 TEST_LOGIN_SECRET이 필요합니다. 비밀과 토큰은 출력하지 않습니다.

    python3 -I tool/store_fixtures.py

열린 시나리오의 권한(getMe, getEntitlements)은 evidence-unlocked에서 복사합니다.
일기와 일정은 사용자가 쓴 글이라 server가 렌더하지 않습니다. 언어마다 손으로 옮긴 데모 글
(`tool/store_user_data.json`)을 쓰고, 그 밖의 값(태그, 날짜, id)은 member fixture 그대로입니다.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

APP_DIR = Path(__file__).resolve().parent.parent
FIXTURES_DIR = APP_DIR / "fixtures"
USER_DATA_PATH = APP_DIR / "tool" / "store_user_data.json"

LANGUAGES = ("ko", "en", "ja")

# 데모 오늘(시나리오 member와 같음)과 그 앞뒤 달(달력 화면이 미리 받는 달).
TODAY = "2026-10-13"
MONTHS = ((2026, 9), (2026, 10), (2026, 11))

# 데모 프로필: member와 같은 출생 정보(실존 인물 아님, D133 ④). 호칭은 언어마다 그 언어 이름입니다.
HONORIFICS = {"ko": "하늘", "en": "Sky", "ja": "そら"}
BIRTH = {
    "calendar": "solar",
    "date": {"year": 1990, "month": 5, "day": 15},
    "isLeapMonth": False,
    "time": {"status": "known", "value": "14:30"},
    "gender": "female",
    "timezone": "Asia/Seoul",
    "place": {"status": "not_asked"},
}


class Client:
    """로컬 server에 JSON 요청을 보냅니다. 실패하면 상태와 problem 본문을 출력하고 끝냅니다."""

    def __init__(self, base: str, secret: str) -> None:
        self.base = base.rstrip("/")
        self.secret = secret
        self.token: str | None = None

    def call(
        self,
        method: str,
        path: str,
        body: Any = None,
        *,
        test_secret: bool = False,
    ) -> tuple[int, dict[str, str], Any]:
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(self.base + path, data=data, method=method)
        request.add_header("Accept", "application/json")
        if data is not None:
            # 프로필 수정(updateProfile)은 JSON Merge Patch입니다(계약).
            content_type = "application/merge-patch+json" if method == "PATCH" else "application/json"
            request.add_header("Content-Type", content_type)
        if test_secret:
            request.add_header("X-Test-Login-Secret", self.secret)
        elif self.token:
            request.add_header("Authorization", f"Bearer {self.token}")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
                headers = {key: value for key, value in response.headers.items()}
                return response.status, headers, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            sys.exit(f"{method} {path} 실패: {error.code} {error.read().decode(errors='replace')}")


def fixture(status: int, body: Any, headers: dict[str, str] | None = None) -> dict[str, Any]:
    """fixture 파일 모양. ETag만 남깁니다(용어 사전 캐시가 씀)."""
    result: dict[str, Any] = {"status": status}
    etag = (headers or {}).get("ETag")
    if etag:
        result["headers"] = {"ETag": etag}
    result["body"] = body
    return result


def write(scenario: str, operation: str, content: dict[str, Any]) -> None:
    path = FIXTURES_DIR / scenario / f"{operation}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(content, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def set_language(client: Client, language: str) -> dict[str, Any]:
    """프로필 언어와 호칭을 바꾸고 updateProfile 응답을 돌려줍니다(server 문장 언어는 프로필 언어, 계약)."""
    status, headers, body = client.call(
        "PATCH",
        "/v1/me/profile",
        {"language": language, "honorific": HONORIFICS[language]},
    )
    return fixture(status, body, headers)


def capture_locked(client: Client, language: str) -> None:
    scenario = f"store-{language}"
    profile = set_language(client, language)
    write(scenario, "updateProfile", profile)
    write(scenario, "createProfile", profile)
    status, headers, body = client.call("GET", f"/v1/daily/{TODAY}")
    write(scenario, "getDaily", fixture(status, body))
    for year, month in MONTHS:
        status, headers, body = client.call("GET", f"/v1/calendar/{year}/{month}")
        write(scenario, f"getCalendar__{year}-{month}", fixture(status, body))
    status, headers, body = client.call("GET", "/v1/chart")
    write(scenario, "getChart", fixture(status, body))
    status, headers, body = client.call("GET", f"/v1/glossary?lang={language}")
    write(scenario, "getGlossary", fixture(status, body, headers))


def capture_unlocked(client: Client, language: str) -> None:
    scenario = f"store-{language}-unlocked"
    set_language(client, language)
    status, headers, body = client.call("GET", f"/v1/daily/{TODAY}")
    if body.get("evidenceAccess") != "unlocked":
        sys.exit(f"{language}: 근거 열람 권한을 준 뒤에도 오늘 응답이 잠겨 있습니다")
    write(scenario, "getDaily", fixture(status, body))
    status, headers, body = client.call("GET", "/v1/chart")
    write(scenario, "getChart", fixture(status, body))


def copy_unlocked_grant() -> None:
    """열린 시나리오는 언어 시나리오(store-<언어>)를 잇고, 근거 열람 권한(getMe, getEntitlements)은
    evidence-unlocked와 같은 광고 한 편 권한을 씁니다(열림 꼬리표 끝 시각, D132)."""
    for language in LANGUAGES:
        for operation in ("getMe", "getEntitlements"):
            source = FIXTURES_DIR / "evidence-unlocked" / f"{operation}.json"
            write(f"store-{language}-unlocked", operation, json.loads(source.read_text(encoding="utf-8")))


def write_user_data() -> None:
    """일기와 일정 데모 글을 언어마다 씁니다.

    * `addSchedules`: 그날 시트 장면(2026-10-12)에 일정이 보이도록 member 일정에 더하는 데모 일정입니다. 세 언어
      모두 씁니다(제목은 언어별).
    * 그 밖의 키(`listSchedules`, `listDiaries`): member fixture 항목 id별로 en, ja 글을 바꿉니다. ko는 member 글
      그대로입니다.
    """
    data = json.loads(USER_DATA_PATH.read_text(encoding="utf-8"))
    added = data.pop("addSchedules")
    schedules = json.loads((FIXTURES_DIR / "member" / "listSchedules.json").read_text(encoding="utf-8"))
    by_language = data.get("listSchedules", {})
    for language in LANGUAGES:
        content = json.loads(json.dumps(schedules))
        items = content["body"]["items"]
        for item in items:
            for field, value in by_language.get(language, {}).get(item["id"], {}).items():
                item[field] = value
        for schedule in added:
            items.append({**schedule, "title": schedule["title"][language]})
        items.sort(key=lambda item: (item["date"], not item["allDay"], item.get("time", "")))
        write(f"store-{language}", "listSchedules", content)
    for operation, by_language in data.items():
        if operation == "listSchedules":
            continue
        source = json.loads((FIXTURES_DIR / "member" / f"{operation}.json").read_text(encoding="utf-8"))
        for language, texts in by_language.items():
            content = json.loads(json.dumps(source))
            for item in content["body"]["items"]:
                for field, value in texts.get(item["id"], {}).items():
                    item[field] = value
            write(f"store-{language}", operation, content)


def main() -> None:
    base = os.environ.get("STORE_API")
    secret = os.environ.get("TEST_LOGIN_SECRET")
    if not base or not secret:
        sys.exit("STORE_API와 TEST_LOGIN_SECRET이 필요합니다(tool/store_fixtures.sh가 채움)")
    client = Client(base, secret)

    _, _, login = client.call("POST", "/test/v1/auth/login", {"label": "storedemo"}, test_secret=True)
    client.token = login["tokens"]["accessToken"]
    _, _, me = client.call("GET", "/v1/me")
    if me["requiredConsents"]:
        client.call("POST", "/v1/me/consents", {"documents": me["requiredConsents"]})
    client.call(
        "PUT",
        "/v1/me/profile",
        {
            "honorific": HONORIFICS["ko"],
            "language": "ko",
            "currentTimezone": "Asia/Seoul",
            "birth": BIRTH,
            "notification": {"status": "not_asked"},
        },
    )

    for language in LANGUAGES:
        capture_locked(client, language)

    # 근거 열람 권한(테스트 광고 제거 기간, S125)을 주고 열린 응답을 받습니다.
    client.call(
        "POST",
        "/test/v1/billing/ad-free",
        {"accountId": me["accountId"], "days": 30},
        test_secret=True,
    )
    for language in LANGUAGES:
        capture_unlocked(client, language)

    copy_unlocked_grant()
    write_user_data()
    print("store fixture를 썼습니다: " + ", ".join(
        f"store-{language}, store-{language}-unlocked" for language in LANGUAGES
    ))


if __name__ == "__main__":
    main()
