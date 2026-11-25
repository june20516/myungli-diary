// 저장소 안 design 토큰 파일과 생성물 경로입니다.

// 빌드 도구가 코드를 묶으면 import.meta.url 기준 경로가 바뀌므로, 저장소 루트는 현재 디렉터리에서 위로 찾습니다.

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { TokenFile, TokenFiles } from "./dtcg.ts";

/** 저장소 루트의 표지 파일(IA, 지휘 소유라 web 단위가 옮기지 않음). */
const REPO_MARKER = "docs/ia/site.json";

/** start(기본 현재 디렉터리)에서 위로 올라가며 표지 파일이 있는 첫 디렉터리. */
export function findRepoRoot(start: string = process.cwd()): string {
  let dir = start;
  for (;;) {
    if (existsSync(join(dir, REPO_MARKER))) return dir;
    const parent = dirname(dir);
    if (parent === dir) throw new Error(`저장소 루트(${REPO_MARKER})를 찾지 못함: ${start}`);
    dir = parent;
  }
}

export const REPO_ROOT = findRepoRoot();
export const DESIGN_TOKENS_DIR = join(REPO_ROOT, "docs/identity/design/tokens/");
export const TOKENS_CSS_PATH = join(REPO_ROOT, "web/packages/tokens/tokens.css");

const FILE_NAMES = {
  primitive: "primitive.tokens.json",
  light: "color.light.tokens.json",
  dark: "color.dark.tokens.json",
  ko: "typography.tokens.json",
  ja: "typography.ja.tokens.json",
} as const;

function readJson(path: string): TokenFile {
  const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error(`토큰 파일이 객체가 아님: ${path}`);
  return parsed as TokenFile;
}

/** 다섯 파일과 README의 계약 버전. */
export function readTokenFiles(dir: string = DESIGN_TOKENS_DIR): { files: TokenFiles; version: string } {
  const files: TokenFiles = {
    primitive: readJson(join(dir, FILE_NAMES.primitive)),
    light: readJson(join(dir, FILE_NAMES.light)),
    dark: readJson(join(dir, FILE_NAMES.dark)),
    ko: readJson(join(dir, FILE_NAMES.ko)),
    ja: readJson(join(dir, FILE_NAMES.ja)),
  };
  const version = /^계약 버전: (\S+)$/m.exec(readFileSync(join(dir, "README.md"), "utf8"))?.[1];
  if (version === undefined) throw new Error(`${join(dir, "README.md")}에서 "계약 버전:" 줄을 찾지 못함`);
  return { files, version };
}
