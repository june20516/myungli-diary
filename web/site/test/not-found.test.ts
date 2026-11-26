import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, test } from "vitest";
import { moveLocalizedNotFound } from "../src/build/not-found.ts";
import { LANGS } from "../src/config/lang.ts";
import { I18N_ROOT, localizedNotFoundFile } from "../src/config/not-found.ts";

const FIREBASE_JSON = fileURLToPath(new URL("../../deploy/firebase/firebase.json", import.meta.url));

describe("언어별 404", () => {
  test("폴더 이름은 Hosting i18n 형식(언어 소문자, _ALL)", () => {
    expect(LANGS.map((lang) => localizedNotFoundFile(lang))).toEqual(["i18n/ko_ALL/404.html", "i18n/en_ALL/404.html", "i18n/ja_ALL/404.html"]);
  });

  test("firebase.json i18n 루트가 같은 폴더", () => {
    const config = JSON.parse(readFileSync(FIREBASE_JSON, "utf8")) as { hosting: { i18n?: { root?: string } } };
    expect(config.hosting.i18n?.root).toBe(`/${I18N_ROOT}`);
  });

  test("빌드된 404/index.html을 404.html로 옮김", () => {
    const dist = mkdtempSync(join(tmpdir(), "dist-"));
    for (const lang of LANGS) {
      const dir = join(dist, I18N_ROOT, `${lang}_ALL`, "404");
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, "index.html"), lang);
    }
    moveLocalizedNotFound(dist);
    for (const lang of LANGS) {
      expect(readFileSync(join(dist, localizedNotFoundFile(lang)), "utf8")).toBe(lang);
      expect(existsSync(join(dist, I18N_ROOT, `${lang}_ALL`, "404"))).toBe(false);
    }
  });

  test("언어별 404가 빌드되지 않았으면 오류", () => {
    expect(() => moveLocalizedNotFound(mkdtempSync(join(tmpdir(), "dist-")))).toThrow(/언어별 404가 빌드되지 않음/);
  });
});
