// IA(site.json)의 랜딩 사이트 화면(web-landing, web-not-found) 슬롯과 writing 웹 원고(#1329)를 맞춰 읽습니다.
// 원고 형식은 `{ "<슬롯 id>": { "<키>": "<문장>" } }`입니다(writing 생성물, #1349).
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { type Lang } from "../config/lang.ts";
import { SITE_IA_PATH, STORE_LISTING_PATH, WRITING_WEB_DIR } from "../config/paths.ts";
import { findD93 } from "../text/d93.ts";

/** 이 사이트가 내는 IA 화면. 원고 한 파일에 두 화면의 슬롯이 함께 들어 있습니다. */
export const SITE_SCREEN_IDS = ["web-landing", "web-not-found"] as const;

/** 슬롯 id → 키 → 문장. */
type SlotTexts = ReadonlyMap<string, ReadonlyMap<string, string>>;

export interface Copy {
  readonly lang: Lang;
  /** 스토어 등록정보의 앱 이름. */
  readonly appName: string;
  /** 슬롯의 문장. 키가 하나인 슬롯은 key를 생략합니다. */
  text(slotId: string, key?: string): string;
  /** 슬롯의 키, 원고 순서대로. */
  keys(slotId: string): readonly string[];
  /** 앱 이름과 모든 문장(글꼴 부분 집합에 씀). */
  allTexts(): readonly string[];
}

export interface LoadCopyOptions {
  readonly iaPath?: string;
  /** writing 생성물 디렉터리(`<언어>.json`). */
  readonly writingDir?: string;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readJsonObject(path: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (!isObject(parsed)) throw new Error(`JSON 객체가 아님: ${path}`);
  return parsed;
}

function asArray(value: unknown, what: string): unknown[] {
  if (!Array.isArray(value)) throw new Error(`${what}이 배열이 아님`);
  return value;
}

/** IA에서 이 사이트 화면들의 슬롯 id 목록, 화면 순서대로. */
export function siteSlotIds(iaPath: string = SITE_IA_PATH): string[] {
  const screens = asArray(readJsonObject(iaPath).screens, "screens");
  return SITE_SCREEN_IDS.flatMap((screenId) => {
    const screen = screens.find((candidate) => isObject(candidate) && candidate.id === screenId);
    if (!isObject(screen)) throw new Error(`IA에 ${screenId} 화면이 없음: ${iaPath}`);
    return asArray(screen.slots, "slots").map((slot) => {
      const id = isObject(slot) ? slot.id : undefined;
      if (typeof id !== "string") throw new Error("슬롯 id가 문자열이 아님");
      return id;
    });
  });
}

function readAppName(lang: Lang): string {
  const byLang = readJsonObject(STORE_LISTING_PATH)[lang];
  const entry = isObject(byLang) ? byLang["store.app-name"] : undefined;
  const appName = isObject(entry) ? entry.appName : undefined;
  if (typeof appName !== "string" || appName === "") throw new Error(`스토어 생성물에 ${lang} 앱 이름이 없음`);
  return appName;
}

function validate(entries: Record<string, unknown>, slotIds: readonly string[], file: string): SlotTexts {
  const problems: string[] = [];
  const known = new Set(slotIds);
  for (const id of slotIds) if (!(id in entries)) problems.push(`missing: ${id}`);
  const slots = new Map<string, Map<string, string>>();
  for (const [id, value] of Object.entries(entries)) {
    if (!known.has(id)) {
      problems.push(`unknown: ${id}`);
      continue;
    }
    if (!isObject(value)) {
      problems.push(`not object: ${id}`);
      continue;
    }
    if (Object.keys(value).length === 0) problems.push(`no keys: ${id}`);
    const texts = new Map<string, string>();
    for (const [key, text] of Object.entries(value)) {
      if (typeof text !== "string" || text.trim() === "") {
        problems.push(`empty: ${id}.${key}`);
        continue;
      }
      for (const found of findD93(text)) problems.push(`D93 ${JSON.stringify(found.char)}: ${id}.${key}`);
      texts.set(key, text);
    }
    slots.set(id, texts);
  }
  if (problems.length > 0) throw new Error(`원고 ${file}가 IA와 맞지 않습니다\n${problems.join("\n")}`);
  return slots;
}

export function loadCopy(lang: Lang, options: LoadCopyOptions = {}): Copy {
  const file = join(options.writingDir ?? WRITING_WEB_DIR, `${lang}.json`);
  if (!existsSync(file)) throw new Error(`writing 웹 원고가 없음: ${file}`);
  const slots = validate(readJsonObject(file), siteSlotIds(options.iaPath), file);
  const appName = readAppName(lang);

  const slotTexts = (slotId: string): ReadonlyMap<string, string> => {
    const texts = slots.get(slotId);
    if (texts === undefined) throw new Error(`원고에 없는 슬롯: ${slotId}`);
    return texts;
  };

  return {
    lang,
    appName,
    text(slotId, key) {
      const texts = slotTexts(slotId);
      if (key === undefined) {
        if (texts.size !== 1) throw new Error(`${slotId}은 키가 ${texts.size}개라 키를 골라야 함`);
        const [only] = texts.values();
        return only ?? "";
      }
      const text = texts.get(key);
      if (text === undefined) throw new Error(`원고 ${slotId}에 없는 키: ${key}`);
      return text;
    },
    keys: (slotId) => [...slotTexts(slotId).keys()],
    allTexts: () => [appName, ...[...slots.values()].flatMap((texts) => [...texts.values()])],
  };
}
