import { describe, expect, test } from "vitest";
import { createSiteConfig } from "../src/config/site.ts";

describe("createSiteConfig", () => {
  test("WEB_ORIGIN이 없으면 로컬 주소", () => {
    expect(createSiteConfig({}).origin).toBe("http://localhost:4321");
  });

  test("WEB_ORIGIN 끝의 빗금은 뗌", () => {
    expect(createSiteConfig({ WEB_ORIGIN: "https://staging.myungli-diary.app/" }).origin).toBe("https://staging.myungli-diary.app");
  });

  test("법적 문서와 지원은 server 주소에 언어", () => {
    expect(createSiteConfig({}).legal("ja")).toEqual({
      terms: "https://api.myungli-diary.app/legal/terms?lang=ja",
      privacy: "https://api.myungli-diary.app/legal/privacy?lang=ja",
      support: "https://api.myungli-diary.app/support?lang=ja",
    });
  });

  test("app-ads.txt 줄", () => {
    expect(createSiteConfig({}).appAdsTxt).toBe("google.com, pub-5703509220233743, DIRECT, f08c47fec0942fa0");
  });

  test("출시 뒤인데 스토어 주소가 비면 오류", () => {
    expect(() => createSiteConfig({}, { release: "live", stores: { apple: "", google: "" } })).toThrow(/스토어 주소/);
  });

  test("출시 전 기본값은 곧 출시", () => {
    expect(createSiteConfig({}).release).toBe("soon");
  });
});
