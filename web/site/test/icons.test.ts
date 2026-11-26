import sharp from "sharp";
import { describe, expect, test } from "vitest";
import { FAVICON_ICO_SIZES, PNG_ICONS, encodeIco, iconSourceName, renderFaviconIco, renderIconPng } from "../src/icons/favicon.ts";

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47];

interface IcoEntry {
  readonly width: number;
  readonly bitCount: number;
  readonly data: Uint8Array;
}

function readIco(ico: Uint8Array): { type: number; entries: IcoEntry[] } {
  const view = new DataView(ico.buffer, ico.byteOffset, ico.byteLength);
  const count = view.getUint16(4, true);
  const entries = Array.from({ length: count }, (_, index) => {
    const entry = 6 + 16 * index;
    const size = view.getUint32(entry + 8, true);
    const offset = view.getUint32(entry + 12, true);
    return { width: view.getUint8(entry) || 256, bitCount: view.getUint16(entry + 6, true), data: ico.slice(offset, offset + size) };
  });
  return { type: view.getUint16(2, true), entries };
}

describe("파비콘", () => {
  test("48px 이하는 작은 크기용 원본, 그보다 크면 큰 원본", () => {
    expect(FAVICON_ICO_SIZES.map((size) => iconSourceName(size))).toEqual(["icon-small.png", "icon-small.png", "icon-small.png"]);
    expect(Object.values(PNG_ICONS).map((icon) => iconSourceName(icon.size))).toEqual(["icon-large.png", "icon-large.png"]);
  });

  test("favicon.ico에 16, 32, 48 PNG가 들어 있고 크기가 맞음", async () => {
    const ico = readIco(await renderFaviconIco());
    expect(ico.type).toBe(1);
    expect(ico.entries.map((entry) => entry.width)).toEqual([...FAVICON_ICO_SIZES]);
    for (const entry of ico.entries) {
      expect([...entry.data.slice(0, 4)]).toEqual(PNG_SIGNATURE);
      expect(entry.bitCount).toBe(32);
      const meta = await sharp(entry.data).metadata();
      expect([meta.width, meta.height]).toEqual([entry.width, entry.width]);
    }
  });

  test.each(Object.values(PNG_ICONS))("$path는 $size px 정사각 PNG", async ({ size }) => {
    const meta = await sharp(await renderIconPng(size)).metadata();
    expect([meta.format, meta.width, meta.height]).toEqual(["png", size, size]);
  });

  test("ICO 크기 256은 0으로 적고 범위 밖은 오류", () => {
    const png = new Uint8Array([1, 2, 3]);
    expect(encodeIco([{ size: 256, png }])[6]).toBe(0);
    expect(() => encodeIco([{ size: 300, png }])).toThrow(/1~256/);
  });
});
