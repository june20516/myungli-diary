import * as hb from "harfbuzzjs";
import { createRequire } from "node:module";
import { describe, expect, test } from "vitest";
import { LANGS, type Lang } from "../src/config/lang.ts";
import { landingFonts, landingTexts } from "../src/fonts/landing.ts";
import { ensureFonts } from "../src/fonts/source.ts";
import { WEB_FACES, fontFaceCss, glyphText, type WebFont } from "../src/fonts/web.ts";

// fontverter 2.1.0의 타입 파일은 module 형식이 아니라, 쓰는 함수만 타입을 정해 불러옵니다.
const fontverter = createRequire(import.meta.url)("fontverter") as { convert(font: Buffer, toFormat: "sfnt"): Promise<Buffer> };

async function unicodes(font: Uint8Array): Promise<Set<number>> {
  const sfnt = await fontverter.convert(Buffer.from(font), "sfnt");
  return new Set(new hb.Face(new hb.Blob(sfnt)).collectUnicodes());
}

describe("glyphText", () => {
  test("겹치지 않게 코드 포인트 순서로 모음", () => {
    expect(glyphText(["ba", "ab", "가"])).toBe("ab가");
  });
});

describe("fontFaceCss", () => {
  test("글꼴마다 @font-face 하나, swap, woff2 경로", () => {
    const font: WebFont = { family: "Gowun Dodum", weight: 400, fileName: "ko-gowun-dodum-400-abc.woff2", data: new Uint8Array() };
    expect(fontFaceCss([font])).toBe(
      '@font-face{font-family:"Gowun Dodum";font-style:normal;font-weight:400;font-display:swap;src:url("/fonts/ko-gowun-dodum-400-abc.woff2") format("woff2")}',
    );
  });
});

describe.each(LANGS)("랜딩 글꼴 %s", (lang: Lang) => {
  test("굵기마다 파일 하나, 이름에 언어와 내용 해시", async () => {
    const fonts = await landingFonts(lang);
    expect(fonts.map((font) => [font.family, font.weight])).toEqual(WEB_FACES[lang].map((face) => [face.family, face.weight]));
    for (const font of fonts) expect(font.fileName).toMatch(new RegExp(`^${lang}-[a-z-]+-\\d{3}-[0-9a-f]{12}\\.woff2$`));
  }, 120_000);

  test("원본이 가진 페이지 글자는 부분 집합에도 모두 있음", async () => {
    const pageCodePoints = [...glyphText(landingTexts(lang))].map((char) => char.codePointAt(0) ?? 0);
    const originals = await ensureFonts(WEB_FACES[lang].map((face) => face.source));
    for (const [index, font] of (await landingFonts(lang)).entries()) {
      const face = WEB_FACES[lang][index];
      const original = face === undefined ? undefined : originals.get(face.source.name);
      expect(original).toBeDefined();
      const originalSet = await unicodes(original ?? new Uint8Array());
      const subsetSet = await unicodes(font.data);
      const missing = pageCodePoints.filter((code) => originalSet.has(code) && !subsetSet.has(code));
      expect(missing, `${font.fileName}에 빠진 글자`).toEqual([]);
    }
  }, 120_000);
});
