import { expect, test } from "@playwright/test";
import { createSiteConfig } from "../site/src/config/site.ts";
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

test("/app-ads.txt는 리다이렉트 없이 text/plain 200", async ({ request }) => {
  const response = await request.get("/app-ads.txt", { maxRedirects: 0 });
  expect(response.status()).toBe(200);
  expect(response.headers()["content-type"]).toMatch(/^text\/plain/);
  expect((await response.text()).trim()).toBe(createSiteConfig({}).appAdsTxt);
});

test("언어 바꾸기로 /ko/에서 /ja/로", async ({ page }) => {
  await page.goto("/ko/");
  await page.locator('header a[hreflang="ja"]').click();
  await expect(page).toHaveURL(`${BASE_URL}/ja/`);
  await expect(page.locator("html")).toHaveAttribute("lang", "ja");
  await expect(page.locator('header a[aria-current="page"]')).toHaveAttribute("hreflang", "ja");
});

test("출시 전에는 스토어 링크가 없음", async ({ page }) => {
  await page.goto("/en/");
  await expect(page.locator('a[href*="apps.apple.com"], a[href*="play.google.com"]')).toHaveCount(0);
});

test("법적 문서와 지원 링크는 server 주소에 그 언어", async ({ page }) => {
  await page.goto("/ja/");
  await expect(page.locator("footer a")).toHaveCount(3);
  await expect(page.locator('footer a[href="https://api.myungli-diary.app/legal/terms?lang=ja"]')).toHaveCount(1);
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

test("없는 주소는 404 상태이고 canonical을 내지 않음", async ({ page }) => {
  const response = await page.goto("/ko/nope/");
  expect(response?.status()).toBe(404);
  await expect(page.locator("link[rel=canonical]")).toHaveCount(0);
  await expect(page.locator("meta[property='og:url']")).toHaveCount(0);
});

test("prod가 아닌 origin은 검색 색인을 막음", async ({ page, request }) => {
  expect((await (await request.get("/robots.txt")).text()).trim()).toBe("User-agent: *\nDisallow: /");
  await page.goto("/en/");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "noindex");
});
