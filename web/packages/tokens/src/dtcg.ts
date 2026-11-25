// DTCG(Format Module 2025.10) 토큰 파일을 읽고 참조를 풉니다.
// 형식 규칙은 docs/identity/design/tokens/README.md "형식"입니다.

export type TokenFile = { readonly [key: string]: unknown };

/** 토큰 파일 하나를 펼친 토큰. value는 파일에 적힌 그대로(참조 포함)입니다. */
export interface RawToken {
  readonly path: readonly string[];
  readonly type: string;
  readonly value: unknown;
  readonly extensions: { readonly [key: string]: unknown };
}

/** 참조를 모두 푼 토큰. */
export interface ResolvedToken {
  readonly path: readonly string[];
  readonly type: string;
  readonly value: unknown;
  readonly extensions: { readonly [key: string]: unknown };
}

export type ColorMode = "light" | "dark";
export type TypographyLang = "ko" | "ja";

/** 테마 하나를 이루는 파일 다섯(README "조합"). */
export interface TokenFiles {
  readonly primitive: TokenFile;
  readonly light: TokenFile;
  readonly dark: TokenFile;
  readonly ko: TokenFile;
  readonly ja: TokenFile;
}

/** 이 저장소가 쓰는 확장 키(README "확장"). */
export const EXTENSION_KEY = "io.github.june20516.myungli-diary";

const REFERENCE = /^\{([^{}]+)\}$/;

export function isRecord(value: unknown): value is { readonly [key: string]: unknown } {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** `"{color.sage.700}"`이면 `color.sage.700`, 아니면 undefined. */
export function referenceTarget(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  return REFERENCE.exec(value)?.[1];
}

export function flatten(file: TokenFile): RawToken[] {
  const tokens: RawToken[] = [];
  const walk = (node: { readonly [key: string]: unknown }, path: string[], inheritedType: string | undefined) => {
    const groupType = typeof node.$type === "string" ? node.$type : inheritedType;
    if ("$value" in node) {
      if (groupType === undefined) throw new Error(`타입이 없는 토큰: ${path.join(".")}`);
      const extensions = isRecord(node.$extensions) ? node.$extensions : {};
      tokens.push({ path, type: groupType, value: node.$value, extensions });
      return;
    }
    for (const [key, child] of Object.entries(node)) {
      if (key.startsWith("$")) continue;
      if (!isRecord(child)) throw new Error(`토큰도 그룹도 아닌 값: ${[...path, key].join(".")}`);
      walk(child, [...path, key], groupType);
    }
  };
  walk(file, [], undefined);
  return tokens;
}

/** 파일들을 합쳐 이름 → 토큰 표로. 서로 다른 파일이 같은 이름을 정의하면 오류입니다. */
function mergeTokens(files: readonly TokenFile[]): Map<string, RawToken> {
  const byName = new Map<string, RawToken>();
  for (const file of files) {
    for (const token of flatten(file)) {
      const name = token.path.join(".");
      if (byName.has(name)) throw new Error(`여러 파일이 같은 토큰을 정의함: ${name}`);
      byName.set(name, token);
    }
  }
  return byName;
}

function resolveValue(value: unknown, byName: Map<string, RawToken>, seen: readonly string[]): unknown {
  const target = referenceTarget(value);
  if (target !== undefined) {
    const referenced = byName.get(target);
    if (referenced === undefined) throw new Error(`깨진 참조: {${target}} (${seen.join(" → ")})`);
    if (seen.includes(target)) throw new Error(`순환 참조: ${[...seen, target].join(" → ")}`);
    return resolveValue(referenced.value, byName, [...seen, target]);
  }
  if (Array.isArray(value)) return value.map((item) => resolveValue(item, byName, seen));
  if (isRecord(value)) {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, resolveValue(item, byName, seen)]));
  }
  return value;
}

/** primitive + 색 모드 파일 하나 + 글자 언어 파일 하나를 합쳐 참조를 모두 풉니다. */
export function loadTheme(files: TokenFiles, mode: ColorMode, typography: TypographyLang): ResolvedToken[] {
  const byName = mergeTokens([files.primitive, files[mode], files[typography]]);
  return [...byName.entries()].map(([name, token]) => ({
    path: token.path,
    type: token.type,
    value: resolveValue(token.value, byName, [name]),
    extensions: token.extensions,
  }));
}
