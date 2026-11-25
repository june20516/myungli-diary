// 사이트 설정 한 곳(#1331 7번): 출시 상태, 스토어 주소, 법적 문서 주소, app-ads.txt, 환경별 origin.
import type { Lang } from "./lang.ts";

export type Release = "soon" | "live";

export interface StoreLinks {
  readonly apple: string;
  readonly google: string;
}

export interface SiteSettings {
  readonly release: Release;
  readonly stores: StoreLinks;
}

export interface SiteConfig extends SiteSettings {
  /** 끝 빗금 없는 origin. OG와 canonical 절대 주소에 씁니다. */
  readonly origin: string;
  legal(lang: Lang): { terms: string; privacy: string; support: string };
  /** /app-ads.txt 본문 한 줄. 게시자 id는 앱 설정(Info.plist)에 이미 공개돼 있습니다. */
  readonly appAdsTxt: string;
  /** 검색 색인 허용. prod origin에서만 참이고, staging과 로컬은 robots와 noindex로 막습니다. */
  readonly indexable: boolean;
}

/** 출시 때 release를 "live"로, stores에 두 스토어 주소를 넣습니다. */
export const SITE_SETTINGS: SiteSettings = {
  release: "soon",
  stores: { apple: "", google: "" },
};

/** prod 랜딩 origin. 이 origin으로 빌드할 때만 검색 색인을 허용합니다. */
export const PROD_ORIGIN = "https://myungli-diary.app";
const LEGAL_ORIGIN = "https://api.myungli-diary.app";
const LOCAL_ORIGIN = "http://localhost:4321";
const APP_ADS_TXT = "google.com, pub-5703509220233743, DIRECT, f08c47fec0942fa0";

export function createSiteConfig(env: { readonly WEB_ORIGIN?: string | undefined }, settings: SiteSettings = SITE_SETTINGS): SiteConfig {
  if (settings.release === "live" && (settings.stores.apple === "" || settings.stores.google === "")) {
    throw new Error("출시 뒤(release: live)에는 두 스토어 주소가 모두 있어야 합니다");
  }
  const origin = (env.WEB_ORIGIN ?? LOCAL_ORIGIN).replace(/\/+$/, "");
  return {
    ...settings,
    origin,
    legal: (lang) => ({
      terms: `${LEGAL_ORIGIN}/legal/terms?lang=${lang}`,
      privacy: `${LEGAL_ORIGIN}/legal/privacy?lang=${lang}`,
      support: `${LEGAL_ORIGIN}/support?lang=${lang}`,
    }),
    appAdsTxt: APP_ADS_TXT,
    indexable: origin === PROD_ORIGIN,
  };
}

/** /robots.txt 본문. */
export function robotsTxt(config: SiteConfig): string {
  return `User-agent: *\n${config.indexable ? "Allow" : "Disallow"}: /\n`;
}

export const siteConfig: SiteConfig = createSiteConfig(process.env);
