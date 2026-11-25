// 정적 생성만 합니다(D144 ⑤, SSR 없음). origin은 빌드 환경 변수 WEB_ORIGIN(배포 환경마다 다름)입니다.
import { defineConfig } from "astro/config";

export default defineConfig({
  output: "static",
  site: process.env.WEB_ORIGIN ?? "http://localhost:4321",
  trailingSlash: "always",
  build: { format: "directory" },
  server: { port: 4321 },
});
