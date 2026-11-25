// 언어별 공유 미리보기 이미지(1200x630 PNG). 공유 이미지는 라이트로 고정합니다(토큰 README "그라데이션").
import { Resvg } from "@resvg/resvg-js";
import satori from "satori";
import type { Lang } from "../config/lang.ts";
import { findD93 } from "../text/d93.ts";
import { OG_FONTS, ensureFonts } from "./fonts.ts";

export const OG_WIDTH = 1200;
export const OG_HEIGHT = 630;

export interface OgInput {
  readonly lang: Lang;
  readonly title: string;
  readonly tagline: string;
  readonly colors: { readonly bg: string; readonly fg: string };
}

const FAMILY = "Pretendard";

export async function renderOg(input: OgInput): Promise<Uint8Array<ArrayBuffer>> {
  for (const [field, text] of [["title", input.title], ["tagline", input.tagline]] as const) {
    if (findD93(text).length > 0) throw new Error(`D93 문자가 든 OG ${field}: ${text}`);
  }
  const [regular, bold] = input.lang === "ja" ? [OG_FONTS.jpRegular, OG_FONTS.jpBold] : [OG_FONTS.regular, OG_FONTS.bold];
  const fonts = await ensureFonts([regular, bold]);
  const fontData = (name: string) => {
    const data = fonts.get(name);
    if (data === undefined) throw new Error(`글꼴이 없음: ${name}`);
    return data;
  };

  const svg = await satori(
    {
      type: "div",
      key: null,
      props: {
        style: {
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: "96px",
          background: input.colors.bg,
          color: input.colors.fg,
          fontFamily: FAMILY,
        },
        children: [
          { type: "div", key: "title", props: { style: { fontSize: 96, fontWeight: 700, marginBottom: 32 }, children: input.title } },
          { type: "div", key: "tagline", props: { style: { fontSize: 44, fontWeight: 400, lineHeight: 1.4, wordBreak: "keep-all" }, children: input.tagline } },
        ],
      },
    },
    {
      width: OG_WIDTH,
      height: OG_HEIGHT,
      fonts: [
        { name: FAMILY, data: fontData(regular.name), weight: 400, style: "normal" },
        { name: FAMILY, data: fontData(bold.name), weight: 700, style: "normal" },
      ],
    },
  );
  return new Uint8Array(new Resvg(svg, { fitTo: { mode: "width", value: OG_WIDTH } }).render().asPng());
}
