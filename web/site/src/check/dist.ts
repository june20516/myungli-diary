// 빌드 산출물 검사: 필요한 파일, 언어별 절대 주소 og:image, 보이는 글의 D93, 같은 origin 링크.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { NodeType, parse, type HTMLElement, type Node } from "node-html-parser";
import { LANGS } from "../config/lang.ts";
import { findD93 } from "../text/d93.ts";

/** 사람이 읽는 글이 들어가는 속성. */
const TEXT_ATTRIBUTES = ["title", "alt", "aria-label", "placeholder"];
const HIDDEN_TEXT_PARENTS = new Set(["script", "style", "noscript"]);

function requiredFiles(): string[] {
  return ["index.html", "app-ads.txt", ...LANGS.flatMap((lang) => [`${lang}/index.html`, `${lang}/og.png`])];
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
      if (!hidden) texts.push(node.rawText);
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

    for (const element of root.querySelectorAll("[href], [src], meta[property='og:image']")) {
      const url = element.getAttribute("href") ?? element.getAttribute("src") ?? element.getAttribute("content") ?? "";
      const target = localTarget(url, origin);
      if (target !== undefined && !existsSync(join(distDir, target))) problems.push(`깨진 링크: ${name} → ${url}`);
    }

    const lang = LANGS.find((candidate) => name === join(candidate, "index.html"));
    if (lang !== undefined) {
      const expected = `${origin}/${lang}/og.png`;
      const actual = root.querySelector("meta[property='og:image']")?.getAttribute("content");
      if (actual !== expected) problems.push(`og:image가 ${expected} 아님: ${name} (${actual ?? "없음"})`);
    }
  }
  return problems;
}
