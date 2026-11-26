// 지원 언어. 지원하지 않는 언어는 en입니다(server S65, app resolveAppLanguage와 같음).
export const LANGS = ["ko", "en", "ja"] as const;
export type Lang = (typeof LANGS)[number];
export const DEFAULT_LANG: Lang = "en";

export function isLang(value: string): value is Lang {
  return (LANGS as readonly string[]).includes(value);
}
