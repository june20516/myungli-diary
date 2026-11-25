import type { Lang } from "../config/lang.ts";

/** og:locale 값. */
export const OG_LOCALE: Record<Lang, string> = { ko: "ko_KR", en: "en_US", ja: "ja_JP" };

/** 언어 바꾸기에 보이는 각 언어의 자기 이름(번역하지 않는 고유 이름). */
export const LANG_NATIVE_NAME: Record<Lang, string> = { ko: "한국어", en: "English", ja: "日本語" };
