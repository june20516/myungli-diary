#!/usr/bin/env python3
"""스토어 이미지(tool/store_images_linux.sh 결과)를 App Store 버전 스크린샷에 올립니다(#1307).

    python3 tool/upload_appstore_images.py [이미지 폴더] [--dry-run]   # 폴더 기본값 .local/store-images

편집할 수 있는 iOS 버전(제출 준비 중, 거절됨)의 언어(ko, en→en-US, ja)마다 iPhone 6.9형
스크린샷(<언어>/appStore/*.png, 파일 이름 순서)을 걸린 스크린샷의 MD5 목록과 순서까지 비교합니다.
같으면 건너뛰고, 다르면 그 세트의 스크린샷을 모두 지운 뒤 순서대로 올립니다(예약, 조각 PUT,
uploaded 표시, 처리 완료 대기). 편집할 수 있는 버전이 없으면(심사 중 등) 아무것도 바꾸지 않고 멈춥니다.

인증은 App Store Connect API Admin 팀 키(로컬 값 K18)로 만든 JWT(ES256)입니다. 서명은 openssl이
하고, 키 파일은 경로로만 다루며 토큰은 출력하지 않습니다(D98). 표준 라이브러리와 openssl만 씁니다.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

APP_ID = "6829967838"
KEY_ID = "LKGA94F3KB"
ISSUER_ID = "0c874e33-b32a-426a-b5a5-a8da26e5e8bf"
API = "https://api.appstoreconnect.apple.com/v1"
# 1320×2868은 App Store Connect의 6.9형 iPhone 자리이고, API 이름은 APP_IPHONE_67입니다.
DISPLAY_TYPE = "APP_IPHONE_67"
# 로컬 폴더 → App Store 언어 코드
LOCALES = {"ko": "ko", "en": "en-US", "ja": "ja"}
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
MAX_SCREENSHOTS = 10
TOKEN_LIFETIME_SECONDS = 15 * 60


def key_path() -> Path:
    local_dir = os.environ.get("MYUNGLI_LOCAL_DIR", str(Path.home() / ".config/myungli"))
    return Path(local_dir) / "app/shared/appstore-connect-admin.p8"


def base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw_signature(der: bytes) -> bytes:
    """openssl이 내는 ECDSA DER 서명(SEQUENCE{r, s})을 JWT의 r||s 64바이트로 바꿉니다."""

    def read_integer(offset: int) -> tuple[bytes, int]:
        if der[offset] != 0x02:
            raise ValueError("DER INTEGER가 아닙니다")
        length = der[offset + 1]
        start = offset + 2
        return der[start : start + length], start + length

    if der[0] != 0x30:
        raise ValueError("DER SEQUENCE가 아닙니다")
    offset = 3 if der[1] & 0x80 else 2
    r, offset = read_integer(offset)
    s, _ = read_integer(offset)
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")


def make_token(private_key: Path) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + TOKEN_LIFETIME_SECONDS,
        "aud": "appstoreconnect-v1",
    }
    signing_input = (
        base64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + base64url(json.dumps(payload, separators=(",", ":")).encode())
    )
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(private_key)],
        input=signing_input.encode(),
        capture_output=True,
        check=True,
    ).stdout
    return signing_input + "." + base64url(der_to_raw_signature(der))


class AppStoreConnect:
    def __init__(self, token: str) -> None:
        self._token = token

    def request(self, method: str, path_or_url: str, body: dict | None = None) -> dict:
        url = path_or_url if path_or_url.startswith("https://") else API + path_or_url
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self._token}")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            raise SystemExit(f"{method} {url.removeprefix(API)} 실패(HTTP {error.code}): {detail}")
        return json.loads(raw) if raw else {}

    def get_all(self, path: str) -> list[dict]:
        items: list[dict] = []
        next_url: str | None = path
        while next_url:
            page = self.request("GET", next_url)
            items.extend(page.get("data", []))
            next_url = page.get("links", {}).get("next")
        return items


def md5_hex(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def find_editable_version(client: AppStoreConnect) -> dict:
    versions = client.get_all(f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=20")
    for version in versions:
        state = version["attributes"].get("appVersionState") or version["attributes"]["appStoreState"]
        print(f"버전 {version['attributes']['versionString']}: {state}")
    editable = [
        v
        for v in versions
        if (v["attributes"].get("appVersionState") or v["attributes"]["appStoreState"]) in EDITABLE_STATES
    ]
    if not editable:
        raise SystemExit("스크린샷을 바꿀 수 있는 버전이 없습니다(심사 중이면 심사에서 빼거나 새 버전이 필요).")
    return editable[0]


def find_or_create_set(client: AppStoreConnect, localization_id: str, dry_run: bool) -> dict | None:
    sets = client.get_all(f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")
    for screenshot_set in sets:
        if screenshot_set["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE:
            return screenshot_set
    if dry_run:
        return None
    return client.request(
        "POST",
        "/appScreenshotSets",
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": localization_id}
                    }
                },
            }
        },
    )["data"]


def upload_screenshot(client: AppStoreConnect, set_id: str, file: Path) -> str:
    content = file.read_bytes()
    reservation = client.request(
        "POST",
        "/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": file.name, "fileSize": len(content)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
            }
        },
    )["data"]
    for operation in reservation["attributes"]["uploadOperations"]:
        chunk = content[operation["offset"] : operation["offset"] + operation["length"]]
        request = urllib.request.Request(operation["url"], data=chunk, method=operation["method"])
        for header in operation.get("requestHeaders", []):
            request.add_header(header["name"], header["value"])
        with urllib.request.urlopen(request):
            pass
    screenshot_id = reservation["id"]
    client.request(
        "PATCH",
        f"/appScreenshots/{screenshot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(content).hexdigest()},
            }
        },
    )
    return screenshot_id


def wait_until_processed(client: AppStoreConnect, screenshot_ids: list[str]) -> None:
    pending = set(screenshot_ids)
    deadline = time.time() + 10 * 60
    while pending:
        for screenshot_id in sorted(pending):
            state = client.request("GET", f"/appScreenshots/{screenshot_id}")["data"]["attributes"][
                "assetDeliveryState"
            ]
            if state["state"] == "COMPLETE":
                pending.discard(screenshot_id)
            elif state["state"] == "FAILED":
                raise SystemExit(f"스크린샷 처리 실패 {screenshot_id}: {state.get('errors')}")
        if pending:
            if time.time() > deadline:
                raise SystemExit(f"10분 안에 처리되지 않은 스크린샷이 있습니다: {sorted(pending)}")
            time.sleep(5)


def sync_locale(client: AppStoreConnect, locale: str, localization_id: str, files: list[Path], dry_run: bool) -> bool:
    screenshot_set = find_or_create_set(client, localization_id, dry_run)
    current = client.get_all(f"/appScreenshotSets/{screenshot_set['id']}/appScreenshots") if screenshot_set else []
    remote = [shot["attributes"].get("sourceFileChecksum") for shot in current]
    expected = [md5_hex(file) for file in files]
    if remote == expected:
        print(f"{locale} {DISPLAY_TYPE}: 같음({len(files)}장), 건너뜀")
        return False
    print(f"{locale} {DISPLAY_TYPE}: 다름(App Store {len(current)}장 → 로컬 {len(files)}장)")
    if dry_run:
        return True
    for shot in current:
        client.request("DELETE", f"/appScreenshots/{shot['id']}")
    uploaded_ids = []
    for file in files:
        uploaded_ids.append(upload_screenshot(client, screenshot_set["id"], file))
        print(f"  올림 {file.parent.parent.name}/{file.parent.name}/{file.name}")
    wait_until_processed(client, uploaded_ids)
    client.request(
        "PATCH",
        f"/appScreenshotSets/{screenshot_set['id']}/relationships/appScreenshots",
        {"data": [{"type": "appScreenshots", "id": screenshot_id} for screenshot_id in uploaded_ids]},
    )
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="App Store 스크린샷을 로컬 스토어 이미지로 맞춥니다.")
    default_dir = Path(__file__).resolve().parent.parent / ".local/store-images"
    parser.add_argument("images_dir", nargs="?", type=Path, default=default_dir)
    parser.add_argument("--dry-run", action="store_true", help="비교만 하고 바꾸지 않습니다.")
    args = parser.parse_args()

    files_by_locale: dict[str, list[Path]] = {}
    for folder, locale in LOCALES.items():
        files = sorted((args.images_dir / folder / "appStore").glob("*.png"))
        if not 1 <= len(files) <= MAX_SCREENSHOTS:
            raise SystemExit(f"App Store 스크린샷은 1~{MAX_SCREENSHOTS}장입니다({folder}: {len(files)}장).")
        files_by_locale[locale] = files

    private_key = key_path()
    if not private_key.is_file():
        raise SystemExit(f"App Store Connect API 키가 없습니다(K18): {private_key}")
    client = AppStoreConnect(make_token(private_key))

    version = find_editable_version(client)
    print(f"대상 버전: {version['attributes']['versionString']}")
    localizations = {
        item["attributes"]["locale"]: item["id"]
        for item in client.get_all(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    }
    missing = sorted(set(files_by_locale) - set(localizations))
    if missing:
        raise SystemExit(f"버전에 없는 언어가 있습니다: {missing} (있는 언어: {sorted(localizations)})")

    changed = 0
    for locale, files in files_by_locale.items():
        if sync_locale(client, locale, localizations[locale], files, args.dry_run):
            changed += 1

    if args.dry_run:
        print(f"dry-run: 바꿀 언어 {changed}개, 아무것도 올리지 않았습니다.")
    elif changed == 0:
        print("App Store 스크린샷이 이미 로컬 판과 같습니다.")
    else:
        print(f"App Store 스크린샷 {changed}개 언어를 바꿨습니다.")


if __name__ == "__main__":
    sys.exit(main())
