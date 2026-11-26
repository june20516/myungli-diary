// 검색 색인 정책. prod origin만 허용합니다(siteConfig.indexable).
import type { APIRoute } from "astro";
import { robotsTxt, siteConfig } from "../config/site.ts";

export const GET: APIRoute = () => new Response(robotsTxt(siteConfig));
