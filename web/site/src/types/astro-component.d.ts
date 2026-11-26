// 일반 tsc가 테스트의 .astro import를 읽도록 하는 선언입니다. astro check는 실제 컴포넌트 타입을 씁니다.
declare module "*.astro" {
  import type { AstroComponentFactory } from "astro/runtime/server/index.js";

  const component: AstroComponentFactory;
  export default component;
}
