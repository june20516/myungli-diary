// 언어별 부분 집합 웹 글꼴. 빌드 때 정적 파일로 만듭니다.
import type { APIRoute, GetStaticPaths } from "astro";
import { allLandingFonts } from "../../fonts/landing.ts";

export const getStaticPaths: GetStaticPaths = async () =>
  (await allLandingFonts()).map((font) => ({ params: { name: font.fileName.replace(/\.woff2$/, "") }, props: { data: font.data } }));

export const GET: APIRoute<{ data: Uint8Array<ArrayBuffer> }> = ({ props }) =>
  new Response(props.data, { headers: { "Content-Type": "font/woff2" } });
