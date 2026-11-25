import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, expect, test } from "vitest";
import { checkDist } from "../src/check/dist.ts";

const ORIGIN = "https://staging.myungli-diary.app";

function page(lang: string, body: string, ogImage = `${ORIGIN}/${lang}/og.png`): string {
  return `<!doctype html><html lang="${lang}"><head><title>제목</title><meta property="og:image" content="${ogImage}"><link rel="canonical" href="${ORIGIN}/${lang}/"></head><body>${body}<a href="/ko/">ko</a><a href="https://example.com/x">밖</a></body></html>`;
}

function makeDist(overrides: Record<string, string | null> = {}): string {
  const dir = mkdtempSync(join(tmpdir(), "dist-"));
  const files: Record<string, string | null> = {
    "index.html": page("en", "<p>언어 고르기</p>"),
    "app-ads.txt": "google.com, pub-1, DIRECT, f08c47fec0942fa0\n",
    "ko/index.html": page("ko", "<p>본문</p>"),
    "en/index.html": page("en", "<p>body</p>"),
    "ja/index.html": page("ja", "<p>本文</p>"),
    "ko/og.png": "png",
    "en/og.png": "png",
    "ja/og.png": "png",
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

  test("깨진 내부 링크는 문제", () => {
    expect(checkDist(makeDist({ "ko/index.html": page("ko", '<a href="/ko/missing/">x</a>') }), ORIGIN)).toContain("깨진 링크: ko/index.html → /ko/missing/");
  });

  test("og:image가 상대 주소면 문제", () => {
    expect(checkDist(makeDist({ "ko/index.html": page("ko", "", "/ko/og.png") }), ORIGIN)).toContain(`og:image가 ${ORIGIN}/ko/og.png 아님: ko/index.html (/ko/og.png)`);
  });
});
