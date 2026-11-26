// 파비콘과 홈 화면 아이콘. design 앱 아이콘 원본에서 빌드 때 만듭니다.
// 48px 이하는 낙관을 키운 작은 크기용(icon-small), 그보다 크면 icon-large입니다(design visual-identity "앱 아이콘").
import { readFileSync } from "node:fs";
import { join } from "node:path";
import sharp from "sharp";
import { DESIGN_LOGO_DIR } from "../config/paths.ts";

/** 이 크기 이하는 icon-small을 씁니다. */
const SMALL_ICON_MAX_PX = 48;

/** favicon.ico 안의 크기(탭, 즐겨찾기, 작업 표시줄). */
export const FAVICON_ICO_SIZES = [16, 32, 48] as const;

/** PNG 아이콘: 경로, 크기. head 링크와 엔드포인트가 같은 표를 씁니다. */
export const PNG_ICONS = {
  touch: { path: "/apple-touch-icon.png", size: 180 },
  large: { path: "/icon-192.png", size: 192 },
} as const;
export type PngIcon = keyof typeof PNG_ICONS;

/** 그 크기에 쓸 design 원본 파일 이름. */
export function iconSourceName(size: number): "icon-small.png" | "icon-large.png" {
  return size <= SMALL_ICON_MAX_PX ? "icon-small.png" : "icon-large.png";
}

export async function renderIconPng(size: number): Promise<Buffer> {
  return sharp(readFileSync(join(DESIGN_LOGO_DIR, iconSourceName(size)))).resize(size, size, { kernel: "lanczos3" }).png({ compressionLevel: 9 }).toBuffer();
}

/** ICO 파일 하나에 PNG 그림 여럿(Windows Vista 이후와 모든 주요 브라우저가 읽는 형식). */
export function encodeIco(images: readonly { readonly size: number; readonly png: Uint8Array }[]): Uint8Array<ArrayBuffer> {
  const HEADER = 6;
  const ENTRY = 16;
  const total = HEADER + ENTRY * images.length + images.reduce((sum, image) => sum + image.png.length, 0);
  const out = new Uint8Array(total);
  const view = new DataView(out.buffer);
  view.setUint16(0, 0, true); // 예약
  view.setUint16(2, 1, true); // 종류: 아이콘
  view.setUint16(4, images.length, true);
  let offset = HEADER + ENTRY * images.length;
  images.forEach((image, index) => {
    if (image.size < 1 || image.size > 256) throw new Error(`ICO 크기는 1~256: ${image.size}`);
    const entry = HEADER + ENTRY * index;
    view.setUint8(entry, image.size % 256); // 256은 0으로 적습니다
    view.setUint8(entry + 1, image.size % 256);
    view.setUint8(entry + 2, 0); // 팔레트 없음
    view.setUint8(entry + 3, 0);
    view.setUint16(entry + 4, 1, true); // 색 평면
    view.setUint16(entry + 6, 32, true); // 픽셀당 비트
    view.setUint32(entry + 8, image.png.length, true);
    view.setUint32(entry + 12, offset, true);
    out.set(image.png, offset);
    offset += image.png.length;
  });
  return out;
}

export async function renderFaviconIco(): Promise<Uint8Array<ArrayBuffer>> {
  const images = await Promise.all(FAVICON_ICO_SIZES.map(async (size) => ({ size, png: await renderIconPng(size) })));
  return encodeIco(images);
}
