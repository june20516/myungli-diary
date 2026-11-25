import js from "@eslint/js";
import astro from "eslint-plugin-astro";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["**/node_modules/", ".cache/", "site/dist/", "site/.astro/", "test-results/", "playwright-report/"] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  // .astro 컴포넌트의 frontmatter와 스크립트도 같은 규칙으로 봅니다.
  ...astro.configs.recommended,
  {
    languageOptions: { globals: { ...globals.node } },
  },
);
