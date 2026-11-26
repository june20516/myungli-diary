// 404를 브라우저 언어로 냅니다(IA web-not-found, #1358). Firebase Hosting i18n 재작성이
// i18n 루트 아래 `<언어>_ALL/404.html`을 Accept-Language 순서로 고르고, 맞는 언어가 없으면 루트 `404.html`(en)을 냅니다.
// https://firebase.google.com/docs/hosting/i18n-rewrites
import type { Lang } from "./lang.ts";

/** firebase.json `hosting.i18n.root`와 같은 폴더(dist 안). */
export const I18N_ROOT = "i18n";

/** 나라와 상관없이 그 언어를 고르는 폴더 이름. 언어 코드는 소문자, ALL은 대문자여야 합니다. */
export function notFoundFolder(lang: Lang): string {
  return `${lang}_ALL`;
}

/** dist 안 언어별 404 파일 경로. */
export function localizedNotFoundFile(lang: Lang): string {
  return `${I18N_ROOT}/${notFoundFolder(lang)}/404.html`;
}
