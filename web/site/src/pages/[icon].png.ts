// 홈 화면과 큰 아이콘(apple-touch-icon 180, icon-192). 경로와 크기는 icons/favicon.ts PNG_ICONS.
import type { APIRoute, GetStaticPaths } from "astro";
import { PNG_ICONS, renderIconPng } from "../icons/favicon.ts";

export const getStaticPaths: GetStaticPaths = () =>
  Object.values(PNG_ICONS).map((icon) => ({ params: { icon: icon.path.slice(1, -".png".length) }, props: { size: icon.size } }));

export const GET: APIRoute<{ size: number }> = async ({ props }) =>
  new Response(new Uint8Array(await renderIconPng(props.size)), { headers: { "Content-Type": "image/png" } });
