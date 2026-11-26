// 웹 글꼴: 언어마다 그 페이지 글자만 남긴 woff2와 @font-face CSS를 빌드 때 만듭니다(V137 "글자와 줄바꿈").
// 글꼴 이름은 토큰(tokens.css)의 font-family 이름과 같아야 합니다.
import { createHash } from "node:crypto";
import subsetFont from "subset-font";
import type { Lang } from "../config/lang.ts";
import { FONTS, ensureFonts, type FontSource } from "./source.ts";

export interface WebFace {
  readonly family: string;
  readonly weight: number;
  readonly source: FontSource;
}

/** 랜딩이 쓰는 굵기: 본문 400, label-md 500, label-lg와 title 600, 문장 글꼴 400. */
const KO_EN_FACES: readonly WebFace[] = [
  { family: "Pretendard", weight: 400, source: FONTS.regular },
  { family: "Pretendard", weight: 500, source: FONTS.medium },
  { family: "Pretendard", weight: 600, source: FONTS.semiBold },
  { family: "Gowun Dodum", weight: 400, source: FONTS.gowunDodum },
];

/** ja는 토큰 `:root:lang(ja)`의 글꼴입니다. */
const JA_FACES: readonly WebFace[] = [
  { family: "Pretendard JP", weight: 400, source: FONTS.jpRegular },
  { family: "Pretendard JP", weight: 500, source: FONTS.jpMedium },
  { family: "Pretendard JP", weight: 600, source: FONTS.jpSemiBold },
  { family: "Zen Maru Gothic", weight: 400, source: FONTS.zenMaruGothic },
];

export const WEB_FACES: Readonly<Record<Lang, readonly WebFace[]>> = { ko: KO_EN_FACES, en: KO_EN_FACES, ja: JA_FACES };

/** 글꼴 파일이 놓이는 경로. 이름에 내용 해시가 있어 오래 캐시합니다(firebase.json). */
export const FONT_URL_DIR = "/fonts/";

export interface WebFont {
  readonly family: string;
  readonly weight: number;
  /** FONT_URL_DIR 아래 파일 이름. */
  readonly fileName: string;
  readonly data: Uint8Array<ArrayBuffer>;
}

/** 글자 모음: 겹치지 않게, 코드 포인트 순서로. 공백은 빼지 않습니다. */
export function glyphText(texts: readonly string[]): string {
  const chars = new Set<string>();
  for (const text of texts) for (const char of text) chars.add(char);
  return [...chars].sort((a, b) => (a.codePointAt(0) ?? 0) - (b.codePointAt(0) ?? 0)).join("");
}

function slug(family: string): string {
  return family.toLowerCase().replace(/\s+/g, "-");
}

function shortHash(data: Uint8Array): string {
  return createHash("sha256").update(data).digest("hex").slice(0, 12);
}

/** 언어 페이지의 글꼴 파일들. texts는 그 페이지에 보이는 모든 글입니다. */
export async function buildWebFonts(lang: Lang, texts: readonly string[], loadSources: typeof ensureFonts = ensureFonts): Promise<WebFont[]> {
  const faces = WEB_FACES[lang];
  const sources = await loadSources(faces.map((face) => face.source));
  const text = glyphText(texts);
  return Promise.all(
    faces.map(async (face) => {
      const original = sources.get(face.source.name);
      if (original === undefined) throw new Error(`글꼴 원본이 없음: ${face.source.name}`);
      const data = new Uint8Array(await subsetFont(original, text, { targetFormat: "woff2" }));
      return { family: face.family, weight: face.weight, fileName: `${lang}-${slug(face.family)}-${face.weight}-${shortHash(data)}.woff2`, data };
    }),
  );
}

/** @font-face 규칙. 글꼴이 늦게 오면 대체 글꼴로 먼저 보여 줍니다(swap). */
export function fontFaceCss(fonts: readonly WebFont[]): string {
  return fonts
    .map(
      (font) =>
        `@font-face{font-family:"${font.family}";font-style:normal;font-weight:${font.weight};font-display:swap;src:url("${FONT_URL_DIR}${font.fileName}") format("woff2")}`,
    )
    .join("\n");
}
