import { expect, test } from "@playwright/test";
import { createSiteConfig } from "../site/src/config/site.ts";
import { loadCopy } from "../site/src/copy/load.ts";
import { BASE_URL } from "./playwright.config.ts";

const LANGS = ["ko", "en", "ja"] as const;

test.describe("언어 고르기(/)", () => {
  for (const [locale, expected] of [
    ["fr-FR", "en"],
    ["zh-TW", "en"],
    ["ja-JP", "ja"],
    ["ko-KR", "ko"],
  ] as const) {
    test(`${locale} → /${expected}/`, async ({ browser }) => {
      const context = await browser.newContext({ locale });
      const page = await context.newPage();
      await page.goto("/");
      await expect(page).toHaveURL(`${BASE_URL}/${expected}/`);
      await context.close();
    });
  }

  test("JS 없이도 세 언어 링크, hreflang, 기본 OG", async ({ browser }) => {
    const context = await browser.newContext({ javaScriptEnabled: false });
    const page = await context.newPage();
    await page.goto("/");
    await expect(page).toHaveURL(`${BASE_URL}/`);
    for (const lang of LANGS) await expect(page.locator(`main a[href="/${lang}/"]`)).toBeVisible();
    await expect(page.locator("link[rel=alternate][hreflang]")).toHaveCount(4);
    await expect(page.locator("meta[property='og:image']")).toHaveAttribute("content", `${BASE_URL}/en/og.png`);
    await context.close();
  });
});

for (const lang of LANGS) {
  test(`/${lang}/ og:image는 그 언어의 절대 주소이고 이미지가 열림`, async ({ page, request }) => {
    await page.goto(`/${lang}/`);
    await expect(page.locator("html")).toHaveAttribute("lang", lang);
    const ogImage = `${BASE_URL}/${lang}/og.png`;
    await expect(page.locator("meta[property='og:image']")).toHaveAttribute("content", ogImage);
    const response = await request.get(ogImage);
    expect(response.status()).toBe(200);
    expect(response.headers()["content-type"]).toBe("image/png");
  });
}

test("파비콘과 홈 화면 아이콘 링크가 열리고, 아이콘 요청에 404가 없음", async ({ page, request }) => {
  const missing: string[] = [];
  page.on("response", (response) => {
    if (response.status() >= 400) missing.push(response.url());
  });
  await page.goto("/ko/");
  for (const [selector, contentType] of [
    ['link[rel="icon"][href="/favicon.ico"]', "image/"],
    ['link[rel="icon"][type="image/png"]', "image/png"],
    ['link[rel="apple-touch-icon"]', "image/png"],
  ] as const) {
    const href = await page.locator(selector).getAttribute("href");
    expect(href, selector).not.toBeNull();
    const response = await request.get(href ?? "");
    expect(response.status(), href ?? "").toBe(200);
    expect(response.headers()["content-type"]).toContain(contentType);
  }
  expect(missing).toEqual([]);
});

test("/app-ads.txt는 리다이렉트 없이 text/plain 200", async ({ request }) => {
  const response = await request.get("/app-ads.txt", { maxRedirects: 0 });
  expect(response.status()).toBe(200);
  expect(response.headers()["content-type"]).toMatch(/^text\/plain/);
  expect((await response.text()).trim()).toBe(createSiteConfig({}).appAdsTxt);
});

test("언어 바꾸기로 /ko/에서 /ja/로", async ({ page }) => {
  await page.goto("/ko/");
  await page.locator('footer nav a[hreflang="ja"]').click();
  await expect(page).toHaveURL(`${BASE_URL}/ja/`);
  await expect(page.locator("html")).toHaveAttribute("lang", "ja");
  await expect(page.locator('footer nav a[aria-current="page"]')).toHaveAttribute("hreflang", "ja");
});

test("출시 전에는 안내 알약 하나, 스토어 링크가 없음", async ({ page }) => {
  await page.goto("/en/");
  await expect(page.locator(".store .soon")).toHaveCount(1);
  await expect(page.locator('a[href*="apps.apple.com"], a[href*="play.google.com"]')).toHaveCount(0);
});

test("법적 문서와 지원 링크는 server 주소에 그 언어", async ({ page }) => {
  await page.goto("/ja/");
  await expect(page.locator("footer .legal a")).toHaveCount(3);
  await expect(page.locator('footer a[href="https://api.myungli-diary.app/legal/terms?lang=ja"]')).toHaveCount(1);
});

// design 명세 V137 "확인한 값": 두 폭에서 가로 넘침 없음, 그 언어의 화면 사진 세 장, 웹 글꼴
const SCENES = ["evidence", "today", "calendar"] as const;
const UI_FONT = { ko: "Pretendard", en: "Pretendard", ja: "Pretendard JP" } as const;

for (const lang of LANGS) {
  for (const viewport of [
    { width: 390, height: 844 },
    { width: 1280, height: 820 },
  ]) {
    test(`/${lang}/ ${viewport.width}폭: 가로 넘침 없음, 사진 세 장, 웹 글꼴`, async ({ page }) => {
      await page.setViewportSize(viewport);
      await page.goto(`/${lang}/`);
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(viewport.width);

      const shots = page.locator("img[data-scene]");
      await expect(shots).toHaveCount(SCENES.length);
      for (const [index, scene] of SCENES.entries()) {
        const shot = shots.nth(index);
        await expect(shot).toHaveAttribute("data-scene", scene);
        await expect(shot).toHaveAttribute("src", new RegExp(`/${lang}-${scene}\\.[\\w-]+\\.webp$`));
        await expect(shot).not.toHaveAttribute("alt", "");
      }
      await expect(shots.nth(1)).toBeInViewport();

      const fonts = await page.evaluate(async () => {
        await document.fonts.ready;
        return [...document.fonts].filter((font) => font.status === "loaded").map((font) => font.family.replace(/"/g, ""));
      });
      expect(fonts).toContain(UI_FONT[lang]);
    });
  }
}

test("다크에서 ko 워드마크는 다크 파일", async ({ browser }) => {
  const context = await browser.newContext({ colorScheme: "dark" });
  const page = await context.newPage();
  await page.goto("/ko/");
  const source = await page.locator(".name picture img").evaluate((image: HTMLImageElement) => image.currentSrc);
  expect(source).toMatch(/wordmark-dark\.[\w-]+\.svg$/);
  await context.close();
});

test("en, ja는 워드마크 대신 앱 이름 글자", async ({ page }) => {
  await page.goto("/ja/");
  await expect(page.locator(".name picture")).toHaveCount(0);
  await expect(page.locator(".name .text")).not.toBeEmpty();
});

test("글꼴 파일은 woff2이고 immutable", async ({ page, request }) => {
  await page.goto("/ko/");
  const css = await page.evaluate(() => [...document.querySelectorAll("head style")].map((style) => style.textContent).join("\n"));
  const fontPath = /@font-face\{[^}]*url\("([^"]+\.woff2)"\)/.exec(css)?.[1];
  expect(fontPath).toBeDefined();
  const response = await request.get(fontPath ?? "");
  expect(response.status()).toBe(200);
  expect(response.headers()["cache-control"]).toBe("public, max-age=31536000, immutable");
});

test.describe("캐시 헤더", () => {
  for (const path of ["/", "/ko/", "/ja/"]) {
    test(`${path} HTML은 no-cache`, async ({ request }) => {
      const response = await request.get(path, { maxRedirects: 0 });
      expect(response.status()).toBe(200);
      expect(response.headers()["cache-control"]).toBe("no-cache");
    });
  }

  test("/_astro/ 파일은 immutable", async ({ page, request }) => {
    await page.goto("/en/");
    const stylesheet = await page.locator('link[rel="stylesheet"][href^="/_astro/"]').first().getAttribute("href");
    expect(stylesheet).not.toBeNull();
    const response = await request.get(stylesheet ?? "");
    expect(response.headers()["cache-control"]).toBe("public, max-age=31536000, immutable");
  });
});

test.describe("없는 주소(404)", () => {
  for (const [locale, lang] of [
    ["ko-KR", "ko"],
    ["ja-JP", "ja"],
    ["en-US", "en"],
    ["fr-FR", "en"],
  ] as const) {
    test(`${locale}: 404 상태, ${lang} 원고, 첫 화면 링크`, async ({ browser }) => {
      const copy = loadCopy(lang);
      const context = await browser.newContext({ locale, viewport: { width: 390, height: 844 } });
      const page = await context.newPage();
      const response = await page.goto("/ko/nope/");
      expect(response?.status()).toBe(404);
      await expect(page.locator("html")).toHaveAttribute("lang", lang);
      await expect(page).toHaveTitle(copy.text("web-not-found.meta.title"));
      await expect(page.locator("h1")).toHaveText(copy.text("web-not-found.page.title"));
      await expect(page.locator("main p")).toHaveText(copy.text("web-not-found.page.body"));
      await expect(page.locator("main a")).toHaveCount(1);
      await expect(page.locator("link[rel=canonical]")).toHaveCount(0);
      await expect(page.locator("meta[property='og:url']")).toHaveCount(0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      await page.getByRole("link", { name: copy.text("web-not-found.page.home") }).click();
      await expect(page).toHaveURL(`${BASE_URL}/${lang}/`);
      await context.close();
    });
  }
});

test("prod가 아닌 origin은 검색 색인을 막음", async ({ page, request }) => {
  expect((await (await request.get("/robots.txt")).text()).trim()).toBe("User-agent: *\nDisallow: /");
  await page.goto("/en/");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "noindex");
});
