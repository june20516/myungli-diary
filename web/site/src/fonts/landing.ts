// 랜딩 언어 페이지가 쓰는 글꼴. 페이지(@font-face)와 글꼴 파일 엔드포인트가 같은 결과를 씁니다.
import { LANGS, type Lang } from "../config/lang.ts";
import { loadCopy } from "../copy/load.ts";
import { LANG_NATIVE_NAME } from "../i18n/locale.ts";
import { buildWebFonts, type WebFont } from "./web.ts";

/** 원고 밖에서 페이지에 보이는 글: 언어 이름, 404 숫자. */
const FIXED_TEXTS: readonly string[] = [...Object.values(LANG_NATIVE_NAME), "0123456789"];

/** 그 언어 페이지에 보일 수 있는 모든 글. */
export function landingTexts(lang: Lang): string[] {
  return [...loadCopy(lang).allTexts(), ...FIXED_TEXTS];
}

const built = new Map<Lang, Promise<WebFont[]>>();

export function landingFonts(lang: Lang): Promise<WebFont[]> {
  let fonts = built.get(lang);
  if (fonts === undefined) {
    fonts = buildWebFonts(lang, landingTexts(lang));
    built.set(lang, fonts);
  }
  return fonts;
}

export async function allLandingFonts(): Promise<WebFont[]> {
  return (await Promise.all(LANGS.map((lang) => landingFonts(lang)))).flat();
}
