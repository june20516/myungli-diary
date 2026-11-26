// Astro는 루트 /404만 404.html로 내고 하위 폴더의 404 페이지는 404/index.html로 냅니다.
// Hosting i18n 재작성이 찾는 이름(404.html)으로 옮깁니다.
import { existsSync, renameSync, rmdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { LANGS } from "../config/lang.ts";
import { localizedNotFoundFile } from "../config/not-found.ts";

export function moveLocalizedNotFound(distDir: string): void {
  for (const lang of LANGS) {
    const target = join(distDir, localizedNotFoundFile(lang));
    const built = join(target.slice(0, -".html".length), "index.html");
    if (!existsSync(built)) throw new Error(`언어별 404가 빌드되지 않음: ${built}`);
    renameSync(built, target);
    rmdirSync(dirname(built));
  }
}
