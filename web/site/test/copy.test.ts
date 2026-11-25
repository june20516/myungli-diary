import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test, vi } from "vitest";
import { LANGS } from "../src/config/lang.ts";
import { landingSlotIds, loadCopy } from "../src/copy/load.ts";

const SLOT_COUNT = 12;

function sourceDirWith(lang: string, entries: Record<string, string>): string {
  const dir = mkdtempSync(join(tmpdir(), "copy-"));
  writeFileSync(join(dir, `${lang}.json`), JSON.stringify(entries));
  return dir;
}

function completeEntries(): Record<string, string> {
  return Object.fromEntries(landingSlotIds().map((id) => [id, `문구 ${id}`]));
}

describe("loadCopy", () => {
  test("IA에 web-landing 슬롯이 12개", () => {
    expect(landingSlotIds()).toHaveLength(SLOT_COUNT);
  });

  test.each(LANGS)("자리 문구 %s가 IA 슬롯과 정확히 맞음", (lang) => {
    const copy = loadCopy(lang, { writingDir: mkdtempSync(join(tmpdir(), "empty-")) });
    expect(copy.source).toBe("placeholder");
    for (const id of landingSlotIds()) expect(copy.text(id, { index: 1 }).length).toBeGreaterThan(0);
  });

  test("자리 문구를 쓰면 언어를 밝혀 경고", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    loadCopy("ja", { writingDir: mkdtempSync(join(tmpdir(), "empty-")) });
    expect(warn).toHaveBeenCalledWith(expect.stringMatching(/자리 문구.*ja/));
    warn.mockRestore();
  });

  test("writing 생성물이 있으면 그것을 씀", () => {
    const copy = loadCopy("ko", { writingDir: sourceDirWith("ko", completeEntries()) });
    expect(copy.source).toBe("writing");
    expect(copy.text("web-landing.hero.tagline")).toBe("문구 web-landing.hero.tagline");
  });

  test("슬롯이 빠지면 오류", () => {
    const entries = completeEntries();
    delete entries["web-landing.hero.body"];
    expect(() => loadCopy("ko", { writingDir: sourceDirWith("ko", entries) })).toThrow(/missing: web-landing\.hero\.body/);
  });

  test("IA에 없는 키는 오류", () => {
    const entries = { ...completeEntries(), "web-landing.extra": "남는 문구" };
    expect(() => loadCopy("ko", { writingDir: sourceDirWith("ko", entries) })).toThrow(/unknown: web-landing\.extra/);
  });

  test("D93 문자가 든 원고는 오류", () => {
    const entries = { ...completeEntries(), "web-landing.hero.tagline": "하루—기록" };
    expect(() => loadCopy("ko", { writingDir: sourceDirWith("ko", entries) })).toThrow(/D93.*web-landing\.hero\.tagline/);
  });

  test("매개변수 index를 채움", () => {
    const entries = { ...completeEntries(), "web-landing.shots.alt": "앱 화면 {index}" };
    const copy = loadCopy("ko", { writingDir: sourceDirWith("ko", entries) });
    expect(copy.text("web-landing.shots.alt", { index: 2 })).toBe("앱 화면 2");
  });

  test("채우지 않은 매개변수가 남으면 오류", () => {
    const entries = { ...completeEntries(), "web-landing.shots.alt": "앱 화면 {index}" };
    const copy = loadCopy("ko", { writingDir: sourceDirWith("ko", entries) });
    expect(() => copy.text("web-landing.shots.alt")).toThrow(/index/);
  });

  test("모르는 슬롯을 읽으면 오류", () => {
    const copy = loadCopy("en", { writingDir: mkdtempSync(join(tmpdir(), "empty-")) });
    expect(() => copy.text("web-landing.nope")).toThrow(/web-landing\.nope/);
  });
});
