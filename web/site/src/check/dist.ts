// 빌드 산출물 검사: 필요한 파일, 언어별 절대 주소 og:image, 보이는 글의 D93, 같은 origin 링크(스타일의 url() 포함), 언어 페이지의 화면 사진.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { NodeType, parse, type HTMLElement, type Node } from "node-html-parser";
import { LANGS } from "../config/lang.ts";
import { localizedNotFoundFile } from "../config/not-found.ts";
import { findD93 } from "../text/d93.ts";

/** 사람이 읽는 글이 들어가는 속성. */
const TEXT_ATTRIBUTES = ["title", "alt", "aria-label", "placeholder"];
/** 사용자에게 보이지 않는 글. noscript는 JS를 끈 사용자에게 보이므로 넣지 않습니다. */
const HIDDEN_TEXT_PARENTS = new Set(["script", "style"]);

function requiredFiles(): string[] {
  return [
    "index.html",
    "404.html",
    "app-ads.txt",
    ...LANGS.flatMap((lang) => [`${lang}/index.html`, `${lang}/og.png`, localizedNotFoundFile(lang)]),
  ];
}

function htmlFiles(dir: string): string[] {
  return readdirSync(dir, { recursive: true, encoding: "utf8" })
    .filter((name) => name.endsWith(".html") && statSync(join(dir, name)).isFile())
    .sort();
}

/** 보이는 글: 텍스트 노드(스크립트, 스타일 밖), 글 속성, meta content. */
function visibleTexts(root: HTMLElement): string[] {
  const texts: string[] = [];
  const walk = (node: Node, hidden: boolean) => {
    if (node.nodeType === NodeType.TEXT_NODE) {
      // 엔티티(&middot; 등)를 푼 글로 봅니다.
      if (!hidden) texts.push(node.text);
      return;
    }
    if (node.nodeType !== NodeType.ELEMENT_NODE) return;
    const element = node as HTMLElement;
    const tag = element.rawTagName?.toLowerCase() ?? "";
    for (const name of TEXT_ATTRIBUTES) {
      const value = element.getAttribute(name);
      if (value !== undefined) texts.push(value);
    }
    if (tag === "meta") {
      const content = element.getAttribute("content");
      if (content !== undefined) texts.push(content);
    }
    for (const child of element.childNodes) walk(child, hidden || HIDDEN_TEXT_PARENTS.has(tag));
  };
  walk(root, false);
  return texts;
}

/** 언어 페이지의 화면 사진 수(V137: 근거, 오늘, 달력). */
const SHOT_COUNT = 3;

/** <style> 안 url(...) 주소(@font-face 글꼴 파일). */
function styleUrls(root: HTMLElement): string[] {
  return root.querySelectorAll("style").flatMap((style: HTMLElement) => [...style.text.matchAll(/url\(\s*["']?([^"')]+)["']?\s*\)/g)].map((match) => match[1] ?? ""));
}

/** 같은 origin 주소면 dist 안 파일 경로, 아니면 undefined. */
function localTarget(url: string, origin: string): string | undefined {
  let path: string;
  if (url.startsWith(`${origin}/`)) path = url.slice(origin.length);
  else if (url.startsWith("/") && !url.startsWith("//")) path = url;
  else return undefined;
  path = path.replace(/[?#].*$/, "");
  return path.endsWith("/") ? `${path.slice(1)}index.html` : path.slice(1);
}

export function checkDist(distDir: string, origin: string): string[] {
  const problems: string[] = [];
  for (const file of requiredFiles()) {
    if (!existsSync(join(distDir, file))) problems.push(`파일 없음: ${file}`);
  }

  for (const file of htmlFiles(distDir)) {
    const root = parse(readFileSync(join(distDir, file), "utf8"));
    const name = relative(distDir, join(distDir, file));

    for (const text of visibleTexts(root)) {
      for (const found of findD93(text)) problems.push(`D93 ${JSON.stringify(found.char)}: ${name} (${text.trim().slice(0, 60)})`);
    }

    const urls = [
      ...root.querySelectorAll("[href], [src], meta[property='og:image']").map((element: HTMLElement) => element.getAttribute("href") ?? element.getAttribute("src") ?? element.getAttribute("content") ?? ""),
      ...root.querySelectorAll("[srcset]").flatMap((element: HTMLElement) => (element.getAttribute("srcset") ?? "").split(",").map((candidate: string) => candidate.trim().split(/\s+/)[0] ?? "")),
      ...styleUrls(root),
    ];
    for (const url of urls) {
      const target = localTarget(url, origin);
      if (target !== undefined && !existsSync(join(distDir, target))) problems.push(`깨진 링크: ${name} → ${url}`);
    }

    const lang = LANGS.find((candidate) => name === join(candidate, "index.html"));
    if (lang !== undefined) {
      const expected = `${origin}/${lang}/og.png`;
      const actual = root.querySelector("meta[property='og:image']")?.getAttribute("content");
      if (actual !== expected) problems.push(`og:image가 ${expected} 아님: ${name} (${actual ?? "없음"})`);
      const shots = root.querySelectorAll("img[data-scene]");
      if (shots.length !== SHOT_COUNT) problems.push(`화면 사진이 ${SHOT_COUNT}장 아님: ${name} (${shots.length}장)`);
      for (const shot of shots) {
        if ((shot.getAttribute("alt") ?? "").trim() === "") problems.push(`화면 사진 alt가 비어 있음: ${name} (${shot.getAttribute("data-scene") ?? ""})`);
      }
    }
  }
  return problems;
}
