import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "vitest";
import { ensureFonts, type FontSource } from "../src/fonts/source.ts";
import { OG_HEIGHT, OG_WIDTH, renderOg } from "../src/og/render.ts";

const colors = { bg: "#f7f6f2", fg: "#2b2b2a" };

function pngSize(png: Uint8Array): { width: number; height: number } {
  const view = new DataView(png.buffer, png.byteOffset, png.byteLength);
  return { width: view.getUint32(16), height: view.getUint32(20) };
}

describe("ensureFonts", () => {
  test("sha256이 다르면 오류", async () => {
    const fonts: FontSource[] = [{ name: "Fake.otf", url: "https://example.invalid/Fake.otf", sha256: "0".repeat(64) }];
    const fetchBytes = async () => new Uint8Array([1, 2, 3]);
    await expect(ensureFonts(fonts, mkdtempSync(join(tmpdir(), "fonts-")), fetchBytes)).rejects.toThrow(/sha256.*Fake\.otf/);
  });
});

describe("renderOg", () => {
  test("1200x630 PNG", async () => {
    const png = await renderOg({ lang: "ko", title: "명리일기", tagline: "오늘 일진을 내 사주에 맞춰 풀어 주는 일기", colors });
    expect([...png.slice(0, 4)]).toEqual([0x89, 0x50, 0x4e, 0x47]);
    expect(pngSize(png)).toEqual({ width: OG_WIDTH, height: OG_HEIGHT });
    expect([OG_WIDTH, OG_HEIGHT]).toEqual([1200, 630]);
  }, 60_000);

  test("일본어도 그림", async () => {
    const png = await renderOg({ lang: "ja", title: "命理日記", tagline: "今日の干支を、あなたの命式に合わせて読み解く日記", colors });
    expect(pngSize(png)).toEqual({ width: 1200, height: 630 });
  }, 60_000);

  test("D93 문자가 든 글은 오류", async () => {
    await expect(renderOg({ lang: "en", title: "Myungli Diary", tagline: "a·b", colors })).rejects.toThrow(/D93/);
  });
});
