// 저장소 안 design 토큰 파일과 생성물 경로입니다.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { TokenFile, TokenFiles } from "./dtcg.ts";

const REPO_ROOT = fileURLToPath(new URL("../../../../", import.meta.url));

export const DESIGN_TOKENS_DIR = `${REPO_ROOT}docs/identity/design/tokens/`;
export const TOKENS_CSS_PATH = fileURLToPath(new URL("../tokens.css", import.meta.url));

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
    primitive: readJson(dir + FILE_NAMES.primitive),
    light: readJson(dir + FILE_NAMES.light),
    dark: readJson(dir + FILE_NAMES.dark),
    ko: readJson(dir + FILE_NAMES.ko),
    ja: readJson(dir + FILE_NAMES.ja),
  };
  const version = /^계약 버전: (\S+)$/m.exec(readFileSync(`${dir}README.md`, "utf8"))?.[1];
  if (version === undefined) throw new Error(`${dir}README.md에서 "계약 버전:" 줄을 찾지 못함`);
  return { files, version };
}
