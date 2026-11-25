// astro build 뒤에 돕니다. 문제가 있으면 목록을 내고 exit 1입니다.
import { fileURLToPath } from "node:url";
import { checkDist } from "../src/check/dist.ts";
import { siteConfig } from "../src/config/site.ts";

const distDir = fileURLToPath(new URL("../dist/", import.meta.url));
const problems = checkDist(distDir, siteConfig.origin);
if (problems.length > 0) {
  console.error(`check-dist: 문제 ${problems.length}개\n${problems.join("\n")}`);
  process.exit(1);
}
console.log(`check-dist: OK (${siteConfig.origin})`);
