// 정적 생성만 합니다(D144 ⑤, SSR 없음). origin은 빌드 환경 변수 WEB_ORIGIN(배포 환경마다 다름)입니다.
import { fileURLToPath } from "node:url";
import { defineConfig } from "astro/config";
import { moveLocalizedNotFound } from "./src/build/not-found.ts";

/** design 계약 파일(로고, 랜딩 화면 사진, V137)을 복사하지 않고 그 자리에서 읽습니다. */
const DESIGN_DIR = fileURLToPath(new URL("../../docs/identity/design/", import.meta.url));

export default defineConfig({
  output: "static",
  site: process.env.WEB_ORIGIN ?? "http://localhost:4321",
  trailingSlash: "always",
  build: { format: "directory" },
  integrations: [
    {
      name: "localized-not-found",
      hooks: { "astro:build:done": ({ dir }) => moveLocalizedNotFound(fileURLToPath(dir)) },
    },
  ],
  server: { port: 4321 },
  vite: {
    resolve: { alias: { "@design/": DESIGN_DIR } },
    server: { fs: { allow: [fileURLToPath(new URL("../..", import.meta.url))] } },
  },
});
