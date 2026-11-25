// OG 이미지 글꼴을 고정 주소에서 받아 sha256으로 확인합니다(design tools/fonts.py와 같은 주소, D81).
// 파일은 저장소에 넣지 않고 web/.cache/fonts/에 둡니다.
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { REPO_ROOT } from "@myungli/tokens";

export interface FontSource {
  readonly name: string;
  readonly url: string;
  readonly sha256: string;
}

const PRETENDARD = "https://cdn.jsdelivr.net/npm/pretendard@1.3.9/dist/public/static";
const PRETENDARD_JP = "https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/packages/pretendard-jp/dist/public/static";

/** 주소는 버전으로 고정합니다. 글꼴을 바꾸면 sha256도 바꿉니다. */
export const OG_FONTS = {
  regular: { name: "Pretendard-Regular.otf", url: `${PRETENDARD}/Pretendard-Regular.otf`, sha256: "3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93" },
  bold: { name: "Pretendard-Bold.otf", url: `${PRETENDARD}/Pretendard-Bold.otf`, sha256: "2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7" },
  jpRegular: { name: "PretendardJP-Regular.otf", url: `${PRETENDARD_JP}/PretendardJP-Regular.otf`, sha256: "8e45c1999c941e8237e52c650c64667638cff1e50b9492c7b02ee1d380b7d06d" },
  jpBold: { name: "PretendardJP-Bold.otf", url: `${PRETENDARD_JP}/PretendardJP-Bold.otf`, sha256: "b7c518afea7212acfc10c99d1ddc0d28912adf906d65ae8ccd7c55b3ef3f6d1a" },
} as const satisfies Record<string, FontSource>;

export const FONT_CACHE_DIR = join(REPO_ROOT, "web/.cache/fonts");

export type FetchBytes = (url: string) => Promise<Uint8Array>;

async function fetchBytes(url: string): Promise<Uint8Array> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`글꼴을 받지 못함(${response.status}): ${url}`);
  return new Uint8Array(await response.arrayBuffer());
}

function sha256(data: Uint8Array): string {
  return createHash("sha256").update(data).digest("hex");
}

/** 없거나 sha256이 다른 글꼴만 받아 캐시에 두고, 이름 → 내용을 돌려줍니다. */
export async function ensureFonts(fonts: readonly FontSource[], cacheDir: string = FONT_CACHE_DIR, fetcher: FetchBytes = fetchBytes): Promise<Map<string, Buffer>> {
  mkdirSync(cacheDir, { recursive: true });
  const loaded = new Map<string, Buffer>();
  for (const font of fonts) {
    const path = join(cacheDir, font.name);
    if (existsSync(path)) {
      const cached = readFileSync(path);
      if (sha256(cached) === font.sha256) {
        loaded.set(font.name, cached);
        continue;
      }
    }
    const data = await fetcher(font.url);
    const actual = sha256(data);
    if (actual !== font.sha256) throw new Error(`sha256이 다름: ${font.name} (기대 ${font.sha256}, 받음 ${actual})`);
    writeFileSync(path, data);
    loaded.set(font.name, Buffer.from(data));
  }
  return loaded;
}
