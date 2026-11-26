// 랜딩 그림(V137 "재료"). 로고와 화면 사진은 design 계약 파일을 그 자리에서 읽고, 스토어 배지는 이 폴더의 공식 파일입니다.
import type { ImageMetadata } from "astro";
import icon from "@design/logo/icon-large.png";
import wordmarkDark from "@design/logo/wordmark-dark.svg?url";
import wordmark from "@design/logo/wordmark.svg?url";
import type { Lang } from "../config/lang.ts";
import { badgeFileName, badgeWidth, type Store } from "./badges.ts";

export { BADGE_HEIGHT } from "./badges.ts";

export { icon };

/** 워드마크(ko만). 원본 비율 228.7 : 64를 높이 30에 맞춘 폭. */
export const WORDMARK = { light: wordmark, dark: wordmarkDark, width: 107, height: 30 } as const;

/** 화면 사진 장면. 왼쪽부터 근거, 오늘(가운데 앞), 달력. 키는 원고 web-landing.shots.alt의 키와 같습니다. */
export const SHOT_SCENES = ["evidence", "today", "calendar"] as const;
export type ShotScene = (typeof SHOT_SCENES)[number];

const shotFiles = import.meta.glob<ImageMetadata>("@design/web/landing/shots/*.webp", { eager: true, import: "default" });

export function shot(lang: Lang, scene: ShotScene): ImageMetadata {
  const entry = Object.entries(shotFiles).find(([path]) => path.endsWith(`/${lang}-${scene}.webp`));
  if (entry === undefined) throw new Error(`화면 사진이 없음: ${lang}-${scene}.webp`);
  return entry[1];
}

export interface StoreBadge {
  readonly src: string;
  /** 높이 BADGE_HEIGHT일 때의 폭(원본 비율). */
  readonly width: number;
}

const badgeFiles = import.meta.glob<string>("./badges/*.{svg,png}", { eager: true, query: "?url", import: "default" });

export function storeBadge(store: Store, lang: Lang): StoreBadge {
  const file = `./badges/${badgeFileName(store, lang)}`;
  const src = badgeFiles[file];
  if (src === undefined) throw new Error(`스토어 배지가 없음: ${file}`);
  return { src, width: badgeWidth(store, lang) };
}
