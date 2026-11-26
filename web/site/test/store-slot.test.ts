import { experimental_AstroContainer as AstroContainer } from "astro/container";
import { parse, type HTMLElement } from "node-html-parser";
import { describe, expect, test } from "vitest";
import StoreSlot from "../src/components/StoreSlot.astro";
import { LANGS } from "../src/config/lang.ts";
import type { Release } from "../src/config/site.ts";
import { loadCopy } from "../src/copy/load.ts";

const STORES = { apple: "https://apps.apple.com/app/id1", google: "https://play.google.com/store/apps/details?id=x" };

async function render(lang: (typeof LANGS)[number], release: Release) {
  const container = await AstroContainer.create();
  const html = await container.renderToString(StoreSlot, { props: { copy: loadCopy(lang), release, stores: STORES } });
  return parse(html);
}

describe("StoreSlot", () => {
  test.each(LANGS)("출시 전 %s: 안내 알약 하나, 링크와 배지 없음", async (lang) => {
    const root = await render(lang, "soon");
    expect(root.querySelectorAll(".soon")).toHaveLength(1);
    expect(root.querySelector(".soon")?.text).toBe(loadCopy(lang).text("web-landing.store.soon"));
    expect(root.querySelectorAll("a, img")).toHaveLength(0);
  });

  test.each(LANGS)("출시 뒤 %s: App Store, Google Play 순서 배지, 그 언어 파일, 접근성 이름", async (lang) => {
    const root = await render(lang, "live");
    const copy = loadCopy(lang);
    expect(root.querySelectorAll(".soon")).toHaveLength(0);
    const links = root.querySelectorAll("a.badge");
    expect(links.map((link: HTMLElement) => link.getAttribute("href"))).toEqual([STORES.apple, STORES.google]);
    expect(links.map((link: HTMLElement) => link.getAttribute("aria-label"))).toEqual([copy.text("web-landing.store.apple"), copy.text("web-landing.store.google")]);
    const sources = links.map((link: HTMLElement) => link.querySelector("img")?.getAttribute("src") ?? "");
    expect(sources[0]).toMatch(new RegExp(`apple-${lang}.*\\.svg`));
    expect(sources[1]).toMatch(new RegExp(`google-${lang}.*\\.png`));
    for (const link of links) expect(link.querySelector("img")?.getAttribute("height")).toBe("48");
  });
});
