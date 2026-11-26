import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "vitest";
import { LANGS } from "../src/config/lang.ts";
import { landingSlotIds, loadCopy } from "../src/copy/load.ts";

const SLOT_COUNT = 12;
const SHOT_ALT = "web-landing.shots.alt";

function writingDirWith(lang: string, entries: unknown): string {
  const dir = mkdtempSync(join(tmpdir(), "copy-"));
  writeFileSync(join(dir, `${lang}.json`), JSON.stringify(entries));
  return dir;
}

function completeEntries(): Record<string, Record<string, string>> {
  return Object.fromEntries(
    landingSlotIds().map((id) => [id, id === SHOT_ALT ? { today: "오늘 사진", calendar: "달력 사진" } : { only: `문구 ${id}` }]),
  );
}

function loadWith(entries: unknown) {
  return loadCopy("ko", { writingDir: writingDirWith("ko", entries) });
}

describe("loadCopy", () => {
  test("IA에 web-landing 슬롯이 12개", () => {
    expect(landingSlotIds()).toHaveLength(SLOT_COUNT);
  });

  test.each(LANGS)("writing 생성물 %s가 IA 슬롯과 정확히 맞음", (lang) => {
    const copy = loadCopy(lang);
    for (const id of landingSlotIds()) {
      for (const key of copy.keys(id)) expect(copy.text(id, key).length).toBeGreaterThan(0);
    }
  });

  test("생성물이 없으면 오류", () => {
    expect(() => loadCopy("ko", { writingDir: mkdtempSync(join(tmpdir(), "empty-")) })).toThrow(/writing 웹 원고가 없음/);
  });

  test("키가 하나인 슬롯은 키 없이 읽음", () => {
    expect(loadWith(completeEntries()).text("web-landing.hero.tagline")).toBe("문구 web-landing.hero.tagline");
  });

  test("키가 여럿인 슬롯은 키로 고름", () => {
    const copy = loadWith(completeEntries());
    expect(copy.keys(SHOT_ALT)).toEqual(["today", "calendar"]);
    expect(copy.text(SHOT_ALT, "calendar")).toBe("달력 사진");
  });

  test("키가 여럿인 슬롯을 키 없이 읽으면 오류", () => {
    expect(() => loadWith(completeEntries()).text(SHOT_ALT)).toThrow(/키를 골라야 함/);
  });

  test("없는 키를 읽으면 오류", () => {
    expect(() => loadWith(completeEntries()).text(SHOT_ALT, "share")).toThrow(/share/);
  });

  test("슬롯이 빠지면 오류", () => {
    const entries = completeEntries();
    delete entries["web-landing.hero.body"];
    expect(() => loadWith(entries)).toThrow(/missing: web-landing\.hero\.body/);
  });

  test("IA에 없는 슬롯은 오류", () => {
    expect(() => loadWith({ ...completeEntries(), "web-landing.extra": { extra: "남는 문구" } })).toThrow(/unknown: web-landing\.extra/);
  });

  test("키가 없는 슬롯은 오류", () => {
    expect(() => loadWith({ ...completeEntries(), "web-landing.hero.body": {} })).toThrow(/no keys: web-landing\.hero\.body/);
  });

  test("슬롯 값이 객체가 아니면 오류", () => {
    expect(() => loadWith({ ...completeEntries(), "web-landing.hero.body": "문장" })).toThrow(/not object: web-landing\.hero\.body/);
  });

  test("빈 문장은 오류", () => {
    expect(() => loadWith({ ...completeEntries(), "web-landing.hero.body": { heroBody: " " } })).toThrow(/empty: web-landing\.hero\.body\.heroBody/);
  });

  test("D93 문자가 든 원고는 오류", () => {
    expect(() => loadWith({ ...completeEntries(), "web-landing.hero.tagline": { heroTagline: "하루—기록" } })).toThrow(
      /D93.*web-landing\.hero\.tagline\.heroTagline/,
    );
  });

  test("모르는 슬롯을 읽으면 오류", () => {
    expect(() => loadWith(completeEntries()).text("web-landing.nope")).toThrow(/web-landing\.nope/);
  });

  test("모든 문장과 앱 이름을 모음", () => {
    const copy = loadWith(completeEntries());
    const texts: readonly string[] = copy.allTexts();
    expect(texts).toContain("달력 사진");
    expect(texts).toContain(copy.appName);
  });
});
