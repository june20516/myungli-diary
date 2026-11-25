// IA(site.json)의 web-landing 슬롯과 원고를 맞춰 읽습니다.
// 원고는 writing 생성물(#1329)이 있으면 그것을, 없으면 자리 문구(placeholder/)를 씁니다.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { type Lang } from "../config/lang.ts";
import { SITE_IA_PATH, STORE_LISTING_PATH, WRITING_WEB_DIR } from "../config/paths.ts";
import { findD93 } from "../text/d93.ts";
import placeholderEn from "./placeholder/en.json" with { type: "json" };
import placeholderJa from "./placeholder/ja.json" with { type: "json" };
import placeholderKo from "./placeholder/ko.json" with { type: "json" };

const LANDING_SCREEN_ID = "web-landing";
/** writing 원고(#1329) 전 자리 문구. 빌드 때 함께 묶이도록 import합니다. */
const PLACEHOLDERS: Record<Lang, Record<string, unknown>> = { ko: placeholderKo, en: placeholderEn, ja: placeholderJa };

export type CopySource = "writing" | "placeholder";
export type CopyParams = Readonly<Record<string, string | number>>;

export interface Copy {
  readonly lang: Lang;
  readonly source: CopySource;
  /** 스토어 등록정보의 앱 이름. */
  readonly appName: string;
  text(slotId: string, params?: CopyParams): string;
}

export interface LoadCopyOptions {
  readonly iaPath?: string;
  /** writing 생성물 디렉터리(`<언어>.json`). */
  readonly writingDir?: string;
}

function readJsonObject(path: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error(`JSON 객체가 아님: ${path}`);
  return parsed as Record<string, unknown>;
}

function asArray(value: unknown, what: string): unknown[] {
  if (!Array.isArray(value)) throw new Error(`${what}이 배열이 아님`);
  return value;
}

/** IA의 web-landing 슬롯 id 목록. */
export function landingSlotIds(iaPath: string = SITE_IA_PATH): string[] {
  const screens = asArray(readJsonObject(iaPath).screens, "screens");
  const landing = screens.find((screen): screen is Record<string, unknown> => typeof screen === "object" && screen !== null && (screen as Record<string, unknown>).id === LANDING_SCREEN_ID);
  if (landing === undefined) throw new Error(`IA에 ${LANDING_SCREEN_ID} 화면이 없음: ${iaPath}`);
  return asArray(landing.slots, "slots").map((slot) => {
    const id = typeof slot === "object" && slot !== null ? (slot as Record<string, unknown>).id : undefined;
    if (typeof id !== "string") throw new Error("슬롯 id가 문자열이 아님");
    return id;
  });
}

function readAppName(lang: Lang): string {
  const byLang = readJsonObject(STORE_LISTING_PATH)[lang];
  const entry = typeof byLang === "object" && byLang !== null ? (byLang as Record<string, unknown>)["store.app-name"] : undefined;
  const appName = typeof entry === "object" && entry !== null ? (entry as Record<string, unknown>).appName : undefined;
  if (typeof appName !== "string" || appName === "") throw new Error(`스토어 생성물에 ${lang} 앱 이름이 없음`);
  return appName;
}

function validate(entries: Record<string, unknown>, slotIds: readonly string[], file: string): Map<string, string> {
  const problems: string[] = [];
  const known = new Set(slotIds);
  for (const id of slotIds) if (!(id in entries)) problems.push(`missing: ${id}`);
  const texts = new Map<string, string>();
  for (const [id, value] of Object.entries(entries)) {
    if (!known.has(id)) {
      problems.push(`unknown: ${id}`);
      continue;
    }
    if (typeof value !== "string" || value.trim() === "") {
      problems.push(`empty: ${id}`);
      continue;
    }
    for (const found of findD93(value)) problems.push(`D93 ${JSON.stringify(found.char)}: ${id}`);
    texts.set(id, value);
  }
  if (problems.length > 0) throw new Error(`원고 ${file}가 IA와 맞지 않습니다\n${problems.join("\n")}`);
  return texts;
}

function fill(template: string, params: CopyParams, slotId: string): string {
  const filled = template.replace(/\{(\w+)\}/g, (whole, name: string) => (name in params ? String(params[name]) : whole));
  const left = /\{(\w+)\}/.exec(filled);
  if (left !== null) throw new Error(`${slotId}의 매개변수 ${left[1]}가 채워지지 않음`);
  return filled;
}

export function loadCopy(lang: Lang, options: LoadCopyOptions = {}): Copy {
  const writingFile = join(options.writingDir ?? WRITING_WEB_DIR, `${lang}.json`);
  const source: CopySource = existsSync(writingFile) ? "writing" : "placeholder";
  const file = source === "writing" ? writingFile : `placeholder/${lang}.json`;
  const entries = source === "writing" ? readJsonObject(writingFile) : PLACEHOLDERS[lang];
  const texts = validate(entries, landingSlotIds(options.iaPath), file);
  return {
    lang,
    source,
    appName: readAppName(lang),
    text(slotId, params = {}) {
      const template = texts.get(slotId);
      if (template === undefined) throw new Error(`원고에 없는 슬롯: ${slotId}`);
      return fill(template, params, slotId);
    },
  };
}
