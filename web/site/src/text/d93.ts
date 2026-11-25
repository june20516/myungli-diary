// D93: 사용자에게 보이는 글에 긴 대시(U+2014), 범위 대시(U+2013), 가운뎃점(U+00B7)을 쓰지 않습니다.
const FORBIDDEN = /[—–·]/gu;

export interface D93Match {
  readonly char: string;
  readonly index: number;
}

export function findD93(text: string): D93Match[] {
  return [...text.matchAll(FORBIDDEN)].map((match) => ({ char: match[0], index: match.index }));
}
