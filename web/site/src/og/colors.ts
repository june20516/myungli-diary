// OG 바탕과 글자색. 토큰 라이트 조합에서 참조를 푼 값을 씁니다.
import { loadTheme, readTokenFiles } from "@myungli/tokens";

function hexOf(name: string): string {
  const token = loadTheme(readTokenFiles().files, "light", "ko").find((candidate) => candidate.path.join(".") === name);
  const value = token?.value;
  const hex = typeof value === "object" && value !== null && "hex" in value ? value.hex : undefined;
  if (typeof hex !== "string") throw new Error(`색 토큰을 찾지 못함: ${name}`);
  return hex;
}

export function ogColors(): { bg: string; fg: string } {
  return { bg: hexOf("color.bg.base"), fg: hexOf("color.text.primary") };
}
