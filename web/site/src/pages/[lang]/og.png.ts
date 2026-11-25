// 언어별 공유 미리보기 이미지. 빌드 때 정적 파일로 만듭니다.
import type { APIRoute, GetStaticPaths } from "astro";
import { LANGS, type Lang } from "../../config/lang.ts";
import { loadCopy } from "../../copy/load.ts";
import { ogColors } from "../../og/colors.ts";
import { renderOg } from "../../og/render.ts";

export const getStaticPaths: GetStaticPaths = () => LANGS.map((lang) => ({ params: { lang } }));

export const GET: APIRoute = async ({ params }) => {
  const lang = params.lang as Lang;
  const copy = loadCopy(lang);
  const png = await renderOg({ lang, title: copy.appName, tagline: copy.text("web-landing.hero.tagline"), colors: ogColors() });
  return new Response(png, { headers: { "Content-Type": "image/png" } });
};
