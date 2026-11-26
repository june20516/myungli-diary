import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { flatten, loadTheme, type TokenFile } from "../src/dtcg.ts";
import { renderCss, toCssVariables } from "../src/css.ts";
import { TOKENS_CSS_PATH, readTokenFiles } from "../src/files.ts";

const color = (hex: string, alpha?: number) => ({
  $type: "color",
  $value: { colorSpace: "srgb", components: [0, 0, 0], hex, ...(alpha === undefined ? {} : { alpha }) },
});

function vars(file: TokenFile): Map<string, string> {
  return toCssVariables(flatten(file));
}

describe("toCssVariables", () => {
  test("색은 hex 그대로", () => {
    expect(vars({ color: { sage: { 700: color("#47634c") } } }).get("--color-sage-700")).toBe("#47634c");
  });

  test("알파가 있는 색은 rgb와 알파", () => {
    expect(vars({ color: { chip: { bg: color("#47634c", 0.7) } } }).get("--color-chip-bg")).toBe("rgb(71 99 76 / 0.7)");
  });

  test("치수와 시간은 값과 단위", () => {
    const result = vars({
      space: { 16: { $type: "dimension", $value: { value: 16, unit: "px" } } },
      motion: { duration: { fade: { $type: "duration", $value: { value: 320, unit: "ms" } } } },
    });
    expect(result.get("--space-16")).toBe("16px");
    expect(result.get("--motion-duration-fade")).toBe("320ms");
  });

  test("곡선은 cubic-bezier", () => {
    const result = vars({ motion: { easing: { standard: { $type: "cubicBezier", $value: [0.2, 0, 0, 1] } } } });
    expect(result.get("--motion-easing-standard")).toBe("cubic-bezier(0.2, 0, 0, 1)");
  });

  test("참조는 var로", () => {
    const result = vars({ color: { bg: { base: { $type: "color", $value: "{color.sage.700}" } } } });
    expect(result.get("--color-bg-base")).toBe("var(--color-sage-700)");
  });

  test("글꼴 묶음은 공백 있는 이름만 따옴표", () => {
    const result = vars({ font: { family: { sentence: { $type: "fontFamily", $value: ["Gowun Dodum", "Pretendard", "sans-serif"] } } } });
    expect(result.get("--font-family-sentence")).toBe('"Gowun Dodum", Pretendard, sans-serif');
  });

  test("글자 복합 토큰은 낱개 변수로, 줄 높이는 단위 없는 배수", () => {
    const result = vars({
      type: {
        numeric: {
          calendar: {
            $type: "typography",
            $value: {
              fontFamily: "{font.family.ui}",
              fontSize: { value: 14, unit: "px" },
              fontWeight: 500,
              letterSpacing: { value: -0.28, unit: "px" },
              lineHeight: 1.2,
            },
            $extensions: { "io.github.june20516.myungli-diary": { fontFeatures: ["tnum"] } },
          },
        },
      },
    });
    expect(result.get("--type-numeric-calendar-font-family")).toBe("var(--font-family-ui)");
    expect(result.get("--type-numeric-calendar-font-size")).toBe("14px");
    expect(result.get("--type-numeric-calendar-font-weight")).toBe("500");
    expect(result.get("--type-numeric-calendar-letter-spacing")).toBe("-0.28px");
    expect(result.get("--type-numeric-calendar-line-height")).toBe("1.2");
    expect(result.get("--type-numeric-calendar-font-feature-settings")).toBe('"tnum"');
  });

  test("그림자는 x y blur spread 색", () => {
    const result = vars({
      shadow: {
        raised: {
          $type: "shadow",
          $value: {
            color: { colorSpace: "srgb", components: [0, 0, 0], hex: "#2b2b2a", alpha: 0.14 },
            offsetX: { value: 0, unit: "px" },
            offsetY: { value: 4, unit: "px" },
            blur: { value: 16, unit: "px" },
            spread: { value: 0, unit: "px" },
          },
        },
      },
    });
    expect(result.get("--shadow-raised")).toBe("0px 4px 16px 0px rgb(43 43 42 / 0.14)");
  });

  test("그라데이션은 확장 각도로 linear-gradient", () => {
    const result = vars({
      gradient: {
        today: {
          $type: "gradient",
          $value: [
            { color: { colorSpace: "srgb", components: [0, 0, 0], hex: "#eef4ef" }, position: 0 },
            { color: { colorSpace: "srgb", components: [0, 0, 0], hex: "#fbefee" }, position: 1 },
          ],
          $extensions: { "io.github.june20516.myungli-diary": { angle: 160 } },
        },
      },
    });
    expect(result.get("--gradient-today")).toBe("linear-gradient(160deg, #eef4ef 0%, #fbefee 100%)");
  });

  test("모르는 타입은 오류", () => {
    expect(() => vars({ x: { $type: "strokeStyle", $value: "solid" } })).toThrow(/strokeStyle/);
  });
});

describe("loadTheme", () => {
  const files = {
    primitive: { color: { sage: { 700: color("#47634c") } } },
    light: { color: { bg: { base: { $type: "color", $value: "{color.sage.700}" } } } },
    dark: { color: { bg: { base: color("#111111") } } },
    ko: {},
    ja: {},
  };

  test("참조를 푼 값", () => {
    const tokens = loadTheme(files, "light", "ko");
    const base = tokens.find((token) => token.path.join(".") === "color.bg.base");
    expect(base?.value).toEqual(files.primitive.color.sage[700].$value);
  });

  test("없는 참조는 오류", () => {
    const broken = { ...files, light: { color: { bg: { base: { $type: "color", $value: "{color.nope}" } } } } };
    expect(() => loadTheme(broken, "light", "ko")).toThrow(/color\.nope/);
  });

  test("서로 다른 파일이 같은 이름을 정의하면 오류", () => {
    const duplicated = { ...files, light: { color: { sage: { 700: color("#000000") }, bg: { base: color("#000000") } } } };
    expect(() => loadTheme(duplicated, "light", "ko")).toThrow(/color\.sage\.700/);
  });
});

describe("renderCss", () => {
  test("짝 파일의 이름 목록이 다르면 오류", () => {
    const files = {
      primitive: {},
      light: { color: { a: color("#000000") } },
      dark: { color: { b: color("#000000") } },
      ko: {},
      ja: {},
    };
    expect(() => renderCss(files, "0.0.0")).toThrow(/짝/);
  });

  test("실제 design 토큰으로 만든 결과가 commit된 tokens.css와 같음", () => {
    const { files, version } = readTokenFiles();
    expect(renderCss(files, version)).toBe(readFileSync(TOKENS_CSS_PATH, "utf8"));
  });

  test("실제 토큰의 네 조합이 모두 풀림", () => {
    const { files } = readTokenFiles();
    for (const mode of ["light", "dark"] as const) {
      for (const typography of ["ko", "ja"] as const) {
        expect(loadTheme(files, mode, typography).length).toBeGreaterThan(100);
      }
    }
  });
});
