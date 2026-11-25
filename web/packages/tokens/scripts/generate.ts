// tokens.css를 만듭니다. --check는 파일을 쓰지 않고, commit된 파일과 다르면 exit 1입니다.
import { readFileSync, writeFileSync } from "node:fs";
import { renderCss } from "../src/css.ts";
import { TOKENS_CSS_PATH, readTokenFiles } from "../src/files.ts";

const { files, version } = readTokenFiles();
const css = renderCss(files, version);

if (process.argv.includes("--check")) {
  let current = "";
  try {
    current = readFileSync(TOKENS_CSS_PATH, "utf8");
  } catch {
    // 파일이 없으면 다른 것으로 봅니다.
  }
  if (current !== css) {
    console.error("tokens.css가 design 토큰과 다릅니다. `pnpm --filter @myungli/tokens generate`로 다시 만들고 commit하세요.");
    process.exit(1);
  }
  console.log(`tokens.css: 토큰 ${version}과 같음`);
} else {
  writeFileSync(TOKENS_CSS_PATH, css);
  console.log(`tokens.css를 만들었습니다(토큰 ${version}).`);
}
