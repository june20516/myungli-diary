// 브라우저가 링크 없이도 찾는 /favicon.ico(16, 32, 48).
import type { APIRoute } from "astro";
import { renderFaviconIco } from "../icons/favicon.ts";

export const GET: APIRoute = async () => new Response(await renderFaviconIco(), { headers: { "Content-Type": "image/x-icon" } });
