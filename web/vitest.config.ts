import { defineConfig } from "vitest/config";

// 패키지마다 자기 vitest 설정이 있으면 그것을, 없으면 기본값으로 돕니다.
export default defineConfig({
  test: {
    projects: ["packages/*"],
  },
});
