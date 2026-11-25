import { expect, test } from "vitest";
import { pickLang } from "../src/i18n/pick.ts";

test.each([
  [["fr"], "en"],
  [["zh-TW", "ja"], "ja"],
  [["ko-KR"], "ko"],
  [[], "en"],
  [["EN-us"], "en"],
  [["ja-JP", "ko"], "ja"],
] as const)("%j → %s", (languages, expected) => {
  expect(pickLang(languages)).toBe(expected);
});
