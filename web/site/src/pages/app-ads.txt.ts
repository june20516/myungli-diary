// AdMob이 개발자 웹사이트 도메인 루트에서 읽습니다. Content-Type은 Hosting 설정(firebase.json)이 정합니다.
import type { APIRoute } from "astro";
import { siteConfig } from "../config/site.ts";

export const GET: APIRoute = () => new Response(`${siteConfig.appAdsTxt}\n`);
