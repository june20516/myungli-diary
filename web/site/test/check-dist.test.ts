import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, expect, test } from "vitest";
import { checkDist } from "../src/check/dist.ts";

const ORIGIN = "https://staging.myungli-diary.app";

function shotImages(scenes: readonly string[] = ["evidence", "today", "calendar"], emptyAlt: readonly string[] = []): string {
  return scenes.map((scene) => `<img src="/ko/og.png" alt="${emptyAlt.includes(scene) ? "" : `${scene} 화면`}" data-scene="${scene}">`).join("");
}

const SHOTS = shotImages();

function page(lang: string, body: string, ogImage = `${ORIGIN}/${lang}/og.png`, shots = SHOTS): string {
  return `<!doctype html><html lang="${lang}"><head><title>제목</title><meta property="og:image" content="${ogImage}"><link rel="canonical" href="${ORIGIN}/${lang}/"></head><body>${body}${shots}<a href="/ko/">ko</a><a href="https://example.com/x">밖</a></body></html>`;
}

function notFoundPage(lang: string): string {
  return `<!doctype html><html lang="${lang}"><head><title>없음</title></head><body><h1>없음</h1><a href="/${lang}/">첫 화면</a></body></html>`;
}

function makeDist(overrides: Record<string, string | null> = {}): string {
  const dir = mkdtempSync(join(tmpdir(), "dist-"));
  const files: Record<string, string | null> = {
    "index.html": page("en", "<p>언어 고르기</p>"),
    "app-ads.txt": "google.com, pub-1, DIRECT, f08c47fec0942fa0\n",
    "favicon.ico": "ico",
    "apple-touch-icon.png": "png",
    "icon-192.png": "png",
    "ko/index.html": page("ko", "<p>본문</p>"),
    "en/index.html": page("en", "<p>body</p>"),
    "ja/index.html": page("ja", "<p>本文</p>"),
    "ko/og.png": "png",
    "en/og.png": "png",
    "ja/og.png": "png",
    "404.html": notFoundPage("en"),
    "i18n/ko_ALL/404.html": notFoundPage("ko"),
    "i18n/en_ALL/404.html": notFoundPage("en"),
    "i18n/ja_ALL/404.html": notFoundPage("ja"),
    ...overrides,
  };
  for (const [name, content] of Object.entries(files)) {
    if (content === null) continue;
    const path = join(dir, name);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
  }
  return dir;
}

describe("checkDist", () => {
  test("정상이면 문제 없음", () => {
    const dir = makeDist();
    expect(checkDist(dir, ORIGIN)).toEqual([]);
    rmSync(dir, { recursive: true });
  });

  test("언어 OG 이미지가 없으면 문제", () => {
    expect(checkDist(makeDist({ "ja/og.png": null }), ORIGIN)).toContain("파일 없음: ja/og.png");
  });

  test("파비콘이 없으면 문제", () => {
    expect(checkDist(makeDist({ "favicon.ico": null }), ORIGIN)).toContain("파일 없음: favicon.ico");
  });

  test("언어별 404가 없으면 문제", () => {
    expect(checkDist(makeDist({ "i18n/ja_ALL/404.html": null }), ORIGIN)).toContain("파일 없음: i18n/ja_ALL/404.html");
  });

  test("본문 가운뎃점은 D93 문제", () => {
    const problems = checkDist(makeDist({ "ko/index.html": page("ko", "<p>일진·기록</p>") }), ORIGIN);
    expect(problems.some((problem) => problem.includes("D93") && problem.includes("ko/index.html") && problem.includes("·"))).toBe(true);
  });

  test("속성 글(alt, aria-label)의 긴 대시도 D93 문제", () => {
    const problems = checkDist(makeDist({ "en/index.html": page("en", '<img src="/en/og.png" alt="a—b">') }), ORIGIN);
    expect(problems.some((problem) => problem.includes("D93") && problem.includes("—"))).toBe(true);
  });

  test("스크립트와 스타일 안의 글자는 보지 않음", () => {
    const problems = checkDist(makeDist({ "en/index.html": page("en", "<script>const a = '·';</script><style>/* — */</style>") }), ORIGIN);
    expect(problems).toEqual([]);
  });

  test("noscript 안의 글은 보이므로 D93 검사", () => {
    const problems = checkDist(makeDist({ "en/index.html": page("en", "<noscript>a·b</noscript>") }), ORIGIN);
    expect(problems.some((problem) => problem.includes("D93"))).toBe(true);
  });

  test("HTML 엔티티로 쓴 가운뎃점도 D93 문제", () => {
    const problems = checkDist(makeDist({ "en/index.html": page("en", "<p>a&middot;b</p>") }), ORIGIN);
    expect(problems.some((problem) => problem.includes("D93"))).toBe(true);
  });

  test("깨진 내부 링크는 문제", () => {
    expect(checkDist(makeDist({ "ko/index.html": page("ko", '<a href="/ko/missing/">x</a>') }), ORIGIN)).toContain("깨진 링크: ko/index.html → /ko/missing/");
  });

  test("og:image가 상대 주소면 문제", () => {
    expect(checkDist(makeDist({ "ko/index.html": page("ko", "", "/ko/og.png") }), ORIGIN)).toContain(`og:image가 ${ORIGIN}/ko/og.png 아님: ko/index.html (/ko/og.png)`);
  });

  test("@font-face 글꼴 파일이 없으면 깨진 링크", () => {
    const style = '<style>@font-face{font-family:"Pretendard";src:url("/fonts/ko-pretendard-400-abc.woff2") format("woff2")}</style>';
    expect(checkDist(makeDist({ "ko/index.html": page("ko", style) }), ORIGIN)).toContain("깨진 링크: ko/index.html → /fonts/ko-pretendard-400-abc.woff2");
  });

  test("@font-face 글꼴 파일이 있으면 문제 없음", () => {
    const style = '<style>@font-face{font-family:"Pretendard";src:url("/fonts/a.woff2") format("woff2")}</style>';
    expect(checkDist(makeDist({ "ko/index.html": page("ko", style), "fonts/a.woff2": "woff2" }), ORIGIN)).toEqual([]);
  });

  test("srcset의 깨진 주소도 문제", () => {
    const picture = '<picture><source srcset="/missing-dark.svg" media="(prefers-color-scheme: dark)"><img src="/ko/og.png" alt="명리일기"></picture>';
    expect(checkDist(makeDist({ "ko/index.html": page("ko", picture) }), ORIGIN)).toContain("깨진 링크: ko/index.html → /missing-dark.svg");
  });

  test("언어 페이지에 화면 사진이 세 장이 아니면 문제", () => {
    expect(checkDist(makeDist({ "ja/index.html": page("ja", "", undefined, shotImages(["evidence", "today"])) }), ORIGIN)).toContain("화면 사진이 3장 아님: ja/index.html (2장)");
  });

  test("화면 사진 alt가 비면 문제", () => {
    expect(checkDist(makeDist({ "en/index.html": page("en", "", undefined, shotImages(undefined, ["today"])) }), ORIGIN)).toContain("화면 사진 alt가 비어 있음: en/index.html (today)");
  });
});
