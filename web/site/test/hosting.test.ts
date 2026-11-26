import { readFileSync } from "node:fs";
import { dirname, isAbsolute, join, normalize, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, test } from "vitest";

const FIREBASE_JSON = fileURLToPath(new URL("../../firebase.json", import.meta.url));
const SITE_DIST = fileURLToPath(new URL("../dist", import.meta.url));

function hostingPublic(): string {
  const config = JSON.parse(readFileSync(FIREBASE_JSON, "utf8")) as { hosting: { public: string } };
  return config.hosting.public;
}

describe("firebase.json Hosting", () => {
  // firebase deploy는 public을 프로젝트 폴더(firebase.json이 있는 곳) 기준으로 풀고, 밖이면 거절합니다.
  // 에뮬레이터는 이 검사를 하지 않아 e2e로는 잡히지 않습니다(#1379). 규칙은 firebase-tools lib/config.js Config.path.
  test("public이 프로젝트 폴더 안", () => {
    const projectDir = dirname(FIREBASE_JSON);
    const publicDir = hostingPublic();
    expect(isAbsolute(publicDir)).toBe(false);
    expect(relative(projectDir, normalize(join(projectDir, publicDir)))).not.toContain("..");
  });

  test("public이 사이트 빌드 출력", () => {
    expect(join(dirname(FIREBASE_JSON), hostingPublic())).toBe(SITE_DIST);
  });
});
