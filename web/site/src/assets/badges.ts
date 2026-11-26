// 두 스토어 공식 배지 파일의 이름과 크기(V137 "스토어 자리").
// Apple은 toolbox.marketingtools.apple.com 검은 배지 SVG 그대로, Google은 play.google.com 배지 PNG의 바깥 투명 여백만 잘라 냈습니다.
import type { Lang } from "../config/lang.ts";

export type Store = "apple" | "google";

/** 배지 높이(V137: Apple 최소 40, Google 최소 28, 둘이 같은 높이). */
export const BADGE_HEIGHT = 48;

/** 원본 크기. Apple은 SVG viewBox, Google은 PNG 픽셀. test/badges.test.ts가 파일과 대조합니다. */
export const BADGE_SIZES: Readonly<Record<`${Store}-${Lang}`, { readonly width: number; readonly height: number }>> = {
  "apple-ko": { width: 129.70071, height: 40 },
  "apple-en": { width: 119.66407, height: 40 },
  "apple-ja": { width: 108.85157, height: 40 },
  "google-ko": { width: 646, height: 192 },
  "google-en": { width: 564, height: 168 },
  "google-ja": { width: 646, height: 192 },
};

export function badgeFileName(store: Store, lang: Lang): string {
  return `${store}-${lang}.${store === "apple" ? "svg" : "png"}`;
}

/** 높이 BADGE_HEIGHT일 때의 폭. */
export function badgeWidth(store: Store, lang: Lang): number {
  const size = BADGE_SIZES[`${store}-${lang}`];
  return Math.round((size.width / size.height) * BADGE_HEIGHT);
}
