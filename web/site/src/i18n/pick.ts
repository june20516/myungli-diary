import { DEFAULT_LANG, isLang, type Lang } from "../config/lang.ts";

/** 브라우저 언어 목록에서 앞에서부터 기본 언어 부분이 처음 맞는 언어. 없으면 en. */
export function pickLang(languages: readonly string[]): Lang {
  for (const tag of languages) {
    const primary = tag.split("-")[0]?.toLowerCase() ?? "";
    if (isLang(primary)) return primary;
  }
  return DEFAULT_LANG;
}
