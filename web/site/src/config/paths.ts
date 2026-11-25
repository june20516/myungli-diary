// 저장소 안에서 사이트가 읽는 계약 파일 경로입니다.
import { fileURLToPath } from "node:url";

const REPO_ROOT = fileURLToPath(new URL("../../../../", import.meta.url));

/** IA 랜딩과 social 화면 목록(D146). */
export const SITE_IA_PATH = `${REPO_ROOT}docs/ia/site.json`;
/** writing 웹 원고 생성물(#1329에서 writing이 정함). 언어마다 `<언어>.json`. */
export const WRITING_WEB_DIR = `${REPO_ROOT}docs/identity/writing/generated/web/`;
/** writing 스토어 등록정보 생성물. 앱 이름을 여기서 읽습니다. */
export const STORE_LISTING_PATH = `${REPO_ROOT}docs/identity/writing/generated/store/listing.json`;
