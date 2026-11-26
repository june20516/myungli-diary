// .astro 컴포넌트를 테스트에서 렌더링하도록 Astro의 Vite 설정(별칭 @design 포함)을 씁니다.
import { fileURLToPath } from "node:url";
import { getViteConfig } from "astro/config";

export default getViteConfig({
  root: fileURLToPath(new URL(".", import.meta.url)),
  test: { include: ["test/**/*.test.ts"] },
});
