// subset-font 2.9.0은 타입을 싣지 않아, 이 사이트가 쓰는 부분만 선언합니다.
declare module "subset-font" {
  interface SubsetFontOptions {
    readonly targetFormat?: "sfnt" | "woff" | "woff2" | "truetype";
  }

  export default function subsetFont(font: Uint8Array, text: string, options?: SubsetFontOptions): Promise<Buffer>;
}
