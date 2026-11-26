import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, test } from "vitest";
import { BADGE_SIZES, badgeFileName, badgeWidth, type Store } from "../src/assets/badges.ts";
import { LANGS } from "../src/config/lang.ts";

const BADGE_DIR = join(import.meta.dirname, "../src/assets/badges");
const STORES: readonly Store[] = ["apple", "google"];

function fileSize(store: Store, file: Buffer): { width: number; height: number } {
  if (store === "google") return { width: file.readUInt32BE(16), height: file.readUInt32BE(20) };
  const viewBox = /viewBox="([\d.\s-]+)"/.exec(file.toString("utf8"))?.[1]?.trim().split(/\s+/).map(Number);
  return { width: viewBox?.[2] ?? 0, height: viewBox?.[3] ?? 0 };
}

describe.each(STORES)("%s 배지", (store) => {
  test.each(LANGS)("%s 파일 크기가 표와 같음", (lang) => {
    const file = readFileSync(join(BADGE_DIR, badgeFileName(store, lang)));
    expect(fileSize(store, file)).toEqual(BADGE_SIZES[`${store}-${lang}`]);
  });
});

test("높이 48일 때 폭", () => {
  expect(badgeWidth("apple", "ko")).toBe(156);
  expect(badgeWidth("google", "en")).toBe(161);
});
