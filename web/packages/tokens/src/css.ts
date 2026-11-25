// 토큰을 CSS 사용자 정의 속성으로 바꿉니다.
// 참조는 var(--…)로 남겨, 다크 모드와 일본어 글꼴이 바뀐 변수만 덮어쓰면 나머지가 따라가게 합니다.

import { EXTENSION_KEY, flatten, isRecord, loadTheme, referenceTarget, type RawToken, type TokenFile, type TokenFiles } from "./dtcg.ts";

const GENERIC_FAMILIES = new Set(["serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "ui-sans-serif", "ui-serif", "ui-monospace"]);

export function variableName(path: readonly string[]): string {
  return `--${path.join("-")}`;
}

function referenceOrUndefined(value: unknown): string | undefined {
  const target = referenceTarget(value);
  return target === undefined ? undefined : `var(${variableName(target.split("."))})`;
}

function fail(name: string, value: unknown): never {
  throw new Error(`값 형식이 맞지 않음: ${name} = ${JSON.stringify(value)}`);
}

function hexChannels(hex: string): [number, number, number] {
  const match = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
  if (match === null) throw new Error(`hex 형식이 아님: ${hex}`);
  return [Number.parseInt(match[1] ?? "", 16), Number.parseInt(match[2] ?? "", 16), Number.parseInt(match[3] ?? "", 16)];
}

function formatColor(value: unknown, name: string): string {
  const reference = referenceOrUndefined(value);
  if (reference !== undefined) return reference;
  if (!isRecord(value) || typeof value.hex !== "string") fail(name, value);
  if (typeof value.alpha !== "number") return value.hex.toLowerCase();
  const [red, green, blue] = hexChannels(value.hex);
  return `rgb(${red} ${green} ${blue} / ${value.alpha})`;
}

function formatMeasure(value: unknown, name: string): string {
  const reference = referenceOrUndefined(value);
  if (reference !== undefined) return reference;
  if (!isRecord(value) || typeof value.value !== "number" || typeof value.unit !== "string") fail(name, value);
  return `${value.value}${value.unit}`;
}

function formatNumber(value: unknown, name: string): string {
  const reference = referenceOrUndefined(value);
  if (reference !== undefined) return reference;
  if (typeof value !== "number") fail(name, value);
  return String(value);
}

function formatFontFamily(value: unknown, name: string): string {
  const reference = referenceOrUndefined(value);
  if (reference !== undefined) return reference;
  const families = typeof value === "string" ? [value] : value;
  if (!Array.isArray(families) || !families.every((family) => typeof family === "string")) fail(name, value);
  return families.map((family: string) => (GENERIC_FAMILIES.has(family) || !/\s/.test(family) ? family : `"${family}"`)).join(", ");
}

function formatCubicBezier(value: unknown, name: string): string {
  const reference = referenceOrUndefined(value);
  if (reference !== undefined) return reference;
  if (!Array.isArray(value) || value.length !== 4 || !value.every((n) => typeof n === "number")) fail(name, value);
  return `cubic-bezier(${value.join(", ")})`;
}

function formatShadow(value: unknown, name: string): string {
  const reference = referenceOrUndefined(value);
  if (reference !== undefined) return reference;
  const layers = Array.isArray(value) ? value : [value];
  return layers
    .map((layer: unknown) => {
      if (!isRecord(layer)) fail(name, value);
      const inset = layer.inset === true ? "inset " : "";
      const parts = [layer.offsetX, layer.offsetY, layer.blur, layer.spread].map((part) => formatMeasure(part, name));
      return `${inset}${parts.join(" ")} ${formatColor(layer.color, name)}`;
    })
    .join(", ");
}

function formatGradient(token: RawToken, name: string): string {
  const reference = referenceOrUndefined(token.value);
  if (reference !== undefined) return reference;
  if (!Array.isArray(token.value)) fail(name, token.value);
  const extension = token.extensions[EXTENSION_KEY];
  const angle = isRecord(extension) && typeof extension.angle === "number" ? extension.angle : 180;
  const stops = token.value.map((stop: unknown) => {
    if (!isRecord(stop) || typeof stop.position !== "number") fail(name, token.value);
    return `${formatColor(stop.color, name)} ${Math.round(stop.position * 10000) / 100}%`;
  });
  return `linear-gradient(${angle}deg, ${stops.join(", ")})`;
}

/** 글자 복합 토큰의 하위 속성과 변수 이름 꼬리. */
const TYPOGRAPHY_PARTS = [
  ["fontFamily", "font-family", formatFontFamily],
  ["fontSize", "font-size", formatMeasure],
  ["fontWeight", "font-weight", formatNumber],
  ["letterSpacing", "letter-spacing", formatMeasure],
  ["lineHeight", "line-height", formatNumber],
] as const;

function typographyVariables(token: RawToken, name: string): [string, string][] {
  if (!isRecord(token.value)) fail(name, token.value);
  const composite = token.value;
  const entries: [string, string][] = [];
  for (const [key, suffix, format] of TYPOGRAPHY_PARTS) {
    if (key in composite) entries.push([`${name}-${suffix}`, format(composite[key], name)]);
  }
  const extension = token.extensions[EXTENSION_KEY];
  if (isRecord(extension) && Array.isArray(extension.fontFeatures)) {
    entries.push([`${name}-font-feature-settings`, extension.fontFeatures.map((feature) => `"${String(feature)}"`).join(", ")]);
  }
  return entries;
}

function tokenVariables(token: RawToken): [string, string][] {
  const name = variableName(token.path);
  switch (token.type) {
    case "color":
      return [[name, formatColor(token.value, name)]];
    case "dimension":
    case "duration":
      return [[name, formatMeasure(token.value, name)]];
    case "number":
    case "fontWeight":
      return [[name, formatNumber(token.value, name)]];
    case "fontFamily":
      return [[name, formatFontFamily(token.value, name)]];
    case "cubicBezier":
      return [[name, formatCubicBezier(token.value, name)]];
    case "shadow":
      return [[name, formatShadow(token.value, name)]];
    case "gradient":
      return [[name, formatGradient(token, name)]];
    case "typography":
      return typographyVariables(token, name);
    default:
      throw new Error(`지원하지 않는 토큰 타입: ${token.type} (${token.path.join(".")})`);
  }
}

export function toCssVariables(tokens: readonly RawToken[]): Map<string, string> {
  const variables = new Map<string, string>();
  for (const token of tokens) {
    for (const [name, value] of tokenVariables(token)) variables.set(name, value);
  }
  return variables;
}

function assertSameNames(left: TokenFile, right: TokenFile, label: string): void {
  const names = (file: TokenFile) => flatten(file).map((token) => token.path.join(".")).sort().join("\n");
  if (names(left) !== names(right)) throw new Error(`짝 파일(${label})의 토큰 이름 목록이 다릅니다`);
}

function block(selector: string, variables: Map<string, string>, indent: string): string {
  const lines = [...variables].map(([name, value]) => `${indent}  ${name}: ${value};`);
  return `${indent}${selector} {\n${lines.join("\n")}\n${indent}}`;
}

/** tokens.css 전체. 기본은 라이트와 한국어 글자, 다크는 시스템 설정, 일본어 글자는 :lang(ja)입니다. */
export function renderCss(files: TokenFiles, version: string): string {
  assertSameNames(files.light, files.dark, "light, dark");
  assertSameNames(files.ko, files.ja, "ko, ja");
  // 네 조합의 참조가 모두 풀리는지와 파일 사이 이름 중복을 여기서 확인합니다.
  for (const mode of ["light", "dark"] as const) {
    for (const typography of ["ko", "ja"] as const) loadTheme(files, mode, typography);
  }
  const base = toCssVariables([...flatten(files.primitive), ...flatten(files.light), ...flatten(files.ko)]);
  const dark = toCssVariables(flatten(files.dark));
  const ja = toCssVariables(flatten(files.ja));
  return [
    `/* 생성물입니다. 손으로 고치지 않습니다. 원본 docs/identity/design/tokens/ (계약 ${version}), 생성기 web/packages/tokens/scripts/generate.ts */`,
    block(":root", base, ""),
    `@media (prefers-color-scheme: dark) {\n${block(":root", dark, "  ")}\n}`,
    block(":root:lang(ja)", ja, ""),
    "",
  ].join("\n");
}
