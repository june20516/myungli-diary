import { expect, test } from "vitest";
import { findD93 } from "../src/text/d93.ts";

test("가운뎃점의 위치를 찾음", () => {
  expect(findD93("a·b")).toEqual([{ char: "·", index: 1 }]);
});

test("긴 대시와 범위 대시를 모두 찾음", () => {
  expect(findD93("x—y–z").map((found) => found.char)).toEqual(["—", "–"]);
});

test("붙임표와 물결은 괜찮음", () => {
  expect(findD93("1~3, co-op")).toEqual([]);
});
