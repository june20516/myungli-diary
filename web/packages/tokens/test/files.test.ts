import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, test } from "vitest";
import { findRepoRoot } from "../src/files.ts";

test("하위 디렉터리에서 위로 올라가 저장소 루트를 찾음", () => {
  const root = mkdtempSync(join(tmpdir(), "repo-"));
  mkdirSync(join(root, "docs/ia"), { recursive: true });
  writeFileSync(join(root, "docs/ia/site.json"), "{}");
  const deep = join(root, "web/site/dist/.prerender/chunks");
  mkdirSync(deep, { recursive: true });
  expect(findRepoRoot(deep)).toBe(root);
});

test("표지 파일이 없으면 오류", () => {
  expect(() => findRepoRoot(mkdtempSync(join(tmpdir(), "none-")))).toThrow(/저장소 루트/);
});
