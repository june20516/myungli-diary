# 공개 디자인 시스템 레퍼런스 조사 (DS1, D107)

* 확인 날짜: 2026-11-05. 지휘 세션의 조사 agent 결과를 옮겼습니다. M3와 HIG는 JS로 그려지는 페이지라 렌더링한 본문을 읽었습니다.
* **(추정)**이 붙은 줄과 "확인 못 함"을 뺀 나머지는 공식 문서 원문에서 확인한 값입니다.
* 쓰는 곳: design의 디자인 시스템 재정비(검수 대장 F-001~F-012). 규칙은 참고만 하고, 다른 시스템의 자산(Figma, 아이콘, 코드)은 가져오지 않습니다. 특히 토스 TDS Figma UI Kit는 "앱인토스 앱 개발에만 허용, 다른 프로젝트에 쓰기·복제·수정 금지"입니다.

## 1. 시스템별 요약
| 시스템 | 공개 범위 | 라이선스 | URL |
| --- | --- | --- | --- |
| 당근 SEED | 토큰, 컴포넌트 53개, 패턴(Loading, Safe Area), 글쓰기와 톤 가이드, 코드(React, CSS, Lynx), Figma | Apache-2.0(GitHub README) | https://seed-design.io , https://github.com/daangn/seed-design |
| 토스 TDS Mobile | 컴포넌트 API 문서(웹 React). 색과 글자 foundation만, 간격 foundation 없음 | Figma UI Kit는 앱인토스 전용(다른 프로젝트 사용 금지). npm `@toss/tds-mobile` license 필드 없음. 규칙 참고만 | https://tossmini-docs.toss.im/tds-mobile/ , https://developers-apps-in-toss.toss.im/design/prepare/figma-ui-license.html |
| 컬리 | 공개 시스템 문서 없음. 원칙 글(2022, 수치 없음)과 Android 구축기 발표만 | 확인 못 함 | https://helloworld.kurly.com/blog/kurly-design-principle/ |
| 무신사 | 공개 시스템 문서 없음. Medium 글 "MDS 지속 가능한 디자인 시스템을 향한 여정"(2025-06)만 | 확인 못 함 | https://medium.com/musinsa-tech |
| Material 3 | 토큰, 컴포넌트, 가이드 전부. Flutter 기본 위젯이 M3 | 오픈소스 구현 | https://m3.material.io |
| Apple HIG | 가이드 위주, 수치 적음 | 가이드 문서 | https://developer.apple.com/design/human-interface-guidelines |
| Shopify Polaris | Admin 웹 시스템, 네이티브 모바일 규칙 없어 제외 | - | https://shopify.dev/apps/tools/polaris |

URL 줄임: `S`=seed-design.io, `T`=tossmini-docs.toss.im/tds-mobile, `M`=m3.material.io, `H`=developer.apple.com/design/human-interface-guidelines

## 2. 항목별 비교

### 간격
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 2px 배수 단계(2 ~ 64, 4px 단위 사이에 6, 10, 14, 18). 화면 좌우 `global-gutter` 16(safe area 기준), 내비와 제목 사이 20, 화면 맨 아래 56, 글 사이 6, 따로 정한 값 없는 컴포넌트 사이 12. 근거로 일관성, 모듈성, 가독성. 섹션 간격 토큰은 없고, 다른 묶음은 선 대신 8px 띄움(Basement 층 위)으로 나눔 | S/foundations/spacing, S/components/divider |
| TDS | 간격 foundation 없음. ListRow 좌우 20 또는 24(기본 24), 위아래 8, 12(기본), 16, 24 | T/components/ListRow/list-row-overview/ |
| M3 | 600dp 미만 좌우 여백 16dp. "A more spacious layout can feel calm and open". 묶음은 근접(implicit)과 경계(explicit). 4dp 격자 원문은 확인 못 함 | M/foundations/layout/breakpoints/compact, M/foundations/layout/grids-spacing/spacing |
| HIG | 시스템 margin, safe area, 가독 폭을 따르라고만 하고 수치 없음. Dynamic Type이 커지면 가로 배치를 세로로 | H/layout |

### 아이콘
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | SEED Icons 약 300개, 굵은 선. 목록 suffix 18px. 크기 단계와 글자 옆 규칙은 확인 못 함 | S/foundations/iconography, S/components/list |
| M3 | Material Symbols 광학 크기 20, 24, 40, 48dp. 선 굵기를 글자 굵기에 맞추고 한 화면에 섞지 않음 | M/styles/icons/applying-icons |
| HIG | SF Symbols 굵기 9단계가 글꼴 굵기와 짝. 크기 small, medium, large가 글꼴 cap height 기준이라 글과 자동 정렬. 글 옆에는 outline 형 | H/sf-symbols |

### 목록 줄
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 좌우 gutter 16(그보다 좁히지 않음), 위아래 12, suffix 18px. 체크박스는 여럿, 라디오는 하나 고르기이며 섞지 않음. 스위치나 체크가 있으면 줄 전체를 누를 수 있음. 구분선은 같은 종류 반복에 subtle, 의미가 바뀌는 곳에 muted(화면당 1~2번), 양쪽을 gutter만큼 들임. 목록으로 이미 나뉘면 선 생략, 마지막 섹션 아래에는 두지 않음 | S/components/list, S/components/divider |
| TDS | 구분선 기본 `indented`(왼쪽 들여쓰기), 붙어 보여야 하면 `none`. 화살표는 `withArrow`(기본 끔). 터치 효과는 onClick이 있을 때만 | T/components/ListRow/list-row-overview/ |
| M3 | 왼쪽 16, 오른쪽 24, 터치 영역 48dp. 들인 구분선 왼쪽 16, 오른쪽 24, 같은 묶음 안. 묶음 사이는 전체 폭 선 | M/components/lists/specs, M/components/divider/guidelines |
| HIG | chevron은 다음 단계로 들어갈 때만. 고르기 목록은 잠깐 강조 뒤 체크 표시. grouped 스타일은 header, footer, 여백으로 나눔 | H/lists-and-tables |

### 버튼
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 위계: 높음(Solid, 화면당 하나), 중간(Weak), 낮음(Outline, Ghost). 한 쌍은 Weak와 Solid, Weak가 닫기·초기화면 3:7. Outline과 Solid 섞지 않음. 셋 이상 나란히 두지 않음. 글이 길면 세로로 쌓음(Responsive Pair). 높이 32, 36, 40, 52 **(토큰에서 계산)** | S/components/action-button |
| TDS | fill(주)와 weak(보조). BottomCTA Single, Double. 아래 여백 `max(safe area, 20px)`. 스크롤하면 숨기는 옵션 | T/components/button/, T/components/BottomCTA/Double/ |
| M3 | 화면당 강조 버튼 하나. filled 옆에 text 또는 outlined. 되돌리기나 빠져나가기는 outlined | M/components/all-buttons |
| HIG | 눈에 띄는 버튼은 화면당 1~2개. 우선 선택은 크기가 아니라 스타일로 구분. 파괴적 동작은 primary로 두지 않음. 최소 44×44pt | H/buttons |

### 바텀시트
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 핸들 36×4(위에서 6), 터치 영역 44. snap point를 쓰면 핸들 필수, 결제나 입력 양식처럼 중요한 작업은 핸들 대신 닫기 버튼. 최대 높이 90%, 단계 2~3개. 넘치면 안쪽 스크롤에 Scroll Fog. 끌어 내리기와 배경 탭으로 닫힘. 헤더 위 24, 아래 16, 푸터 위 12, 아래 16, 좌우 gutter, 최대 폭 480 | S/components/bottom-sheet |
| TDS | CTA와 본문 사이 34px. 위로 10px 끌면 전체 높이로 펼치는 옵션. 배경 탭, 뒤로가기로 닫힘 | T/components/bottom-sheet/ |
| M3 | 핸들 위아래 22dp, 위쪽 여백 72dp, 최대 폭 640. 모달은 처음 높이 50% 이하, 끌어 내리기와 배경 탭으로 닫힘. 핸들 탭으로 높이 단계 오감 | M/components/bottom-sheets/specs, M/components/bottom-sheets/guidelines |
| HIG | detent medium(약 절반)과 large. 크기를 바꿀 수 있으면 grabber. 세로로 밀어 닫기, 저장 안 한 변경이 있으면 확인 | H/sheets |

### 확인 창
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 안쪽 여백 20, 제목과 설명 6, 버튼 사이 8, 최대 폭 272. 동작 2개까지, 기본 가로, 길면 세로. 설명 필수. 바깥 탭으로 닫지 않음 | S/components/alert-dialog |
| TDS | 짧으면 가로, 길면 세로로 쌓아 전체 폭. 취소는 dark weak. 기본은 배경 탭으로 닫힘, 막으면 흔들림 | T/components/Dialog/confirm-dialog/ |
| M3 | 안쪽 여백 24, 제목과 본문 16, 본문과 버튼 24, 버튼 사이 8, 모서리 28, 폭 280~560. 아이콘 24dp가 있으면 가운데 정렬. 버튼 끝 정렬 | M/components/dialogs/specs |
| HIG | 버튼 3개까지. 기본 버튼은 줄이면 끝, 쌓으면 맨 위. 취소는 앞이나 맨 아래. 파괴적 스타일은 의도하지 않은 파괴적 동작에만. 되돌릴 수 있는 삭제에는 확인 창을 띄우지 않음. "OK" 피함 | H/alerts |

### 눌림, 로딩, 화면 전환
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 눌림은 표면 색 변화 기본, 가능하면 살짝 축소(150ms), 동작 줄이기 설정에서는 축소 안 함. 목록 줄 눌림 배경은 좌우 6 들이고 radius 10. skeleton은 실제 크기에 맞추고 radius 글 8, 카드 16, shimmer 1.5s, 스피너와 함께 쓰지 않음. 시간 토큰 50~300ms, enter·exit easing. push와 모달 전환 기본값은 정하지 않음 | S/foundations/feedback, S/foundations/state, S/components/skeleton, S/foundations/motion |
| TDS | 눌림은 dim 층. 로딩 버튼은 점 3개, 너비 그대로. skeleton 모양 프리셋(title, subtitle, list, card) | T/components/button/, T/components/skeleton/ |
| M3 | 상태 레이어: 눌림 10%, hover 8%, 포커스 10%, 끌기 16%. 전환 패턴 container transform, forward/backward(플랫폼별 기본), lateral, top level | M/foundations/interaction/states/state-layers, M/styles/motion/transitions/transition-patterns |
| HIG | 로딩은 되도록 빨리 무언가를 보여 주고 placeholder를 채워 넣음 | H/loading |

### 섹션 제목과 화면 구성
| 시스템 | 규칙 | 근거 |
| --- | --- | --- |
| SEED | 섹션 제목 컴포넌트는 확인 못 함. 큰 묶음은 Basement 층 위 8px 간격 | S/components/divider |
| TDS | ListHeader: 제목(t7, t5, t4)과 오른쪽 글자나 화살표, 설명은 위나 아래. 제목 폭 비율 0.66, 글자 200% 이상에서 0.5 | T/components/list-header/ |
| M3 | 명시적 묶음(테두리, 카드, 선)과 암시적 묶음(근접) | M/foundations/layout/grids-spacing/spacing |
| HIG | grouped 목록의 header, footer, 여백 | H/lists-and-tables |

## 3. 조사 agent의 추천 (규칙은 사실 근거, 이유는 판단)
1. 간격은 4px 단계에 2px 배수 세부값 허용, 화면 좌우 여백 토큰 하나(SEED, M3는 16. 지금 우리는 `space.20`)
2. 구분은 "들인 선, 전체 폭 선, 선 없이 간격과 바탕 층" 3단계. 마지막 섹션 아래에는 선 없음(SEED)
3. 목록 구분선은 기본 들여쓰기, 들인 위치는 줄의 글 시작점(TDS, M3)
4. chevron은 다음 화면으로 들어갈 때만, 고르기 목록은 체크(하나)나 체크박스(여럿), 섞지 않음(HIG, SEED)
5. 버튼 위계 3단, 강조 버튼은 화면당 하나, 두 버튼은 같은 높이로 스타일로만 구분(HIG), 보조와 주 동작 3:7(SEED)
6. 두 버튼은 기본 가로, 글이 넘치면 세로로 쌓고 주 버튼이 위(SEED, TDS, HIG). en, ja가 길어지기 쉬워 자동 전환 필수
7. 아래 고정 버튼 아래 여백 `max(safe area, 20)`(TDS)
8. 바텀시트 핸들 36×4, 높이 단계 최대 90%와 절반. 입력이 있는 시트는 핸들 대신 닫기 버튼과 저장 확인(SEED, HIG)
9. 확인 창은 버튼 2개까지, 설명 필수, 바깥 탭으로 닫지 않음. 파괴적 스타일은 의도하지 않은 삭제에만, 되돌릴 수 있는 삭제는 실행 취소(SEED, HIG)
10. 눌림은 색 변화 기본 150ms, 축소는 큰 카드에만, 동작 줄이기 설정에서 끔(SEED). 차분한 톤에는 퍼지는 ripple보다 색 변화(판단)
11. skeleton은 실제 글 줄 모양(글 radius 8, 카드 16), 스피너와 함께 쓰지 않음(SEED)
12. 아이콘 선 굵기를 본문 글꼴 굵기에 맞추고, 크기는 글자 높이 기준 2~3단계(SF Symbols, M3). px 단계는 공통값이 없어 직접 정함
13. 섹션 제목은 하나의 컴포넌트(제목, 선택 설명, 오른쪽 더 보기)로 고정, 글자 확대 때 제목 폭 비율 규칙(TDS ListHeader)

## 4. 확인 못 한 것
* SEED: 아이콘 크기 단계와 글자 옆 규칙, chevron 조건, 버튼 사이 간격, 아래 고정 버튼, 섹션 제목 컴포넌트, push 전환 기본값
* TDS: 아이콘, skeleton 애니메이션과 radius, 시트 핸들 크기, 확인 창 여백, 두 버튼 비율과 간격
* M3: 4dp 격자 원문, 목록 줄 높이(88dp 기준값만 확인), skeleton
* HIG: iOS 여백 수치, 눌림과 skeleton 사양
* 컬리, 무신사: 공개 시스템 자체
* Flutter 플랫폼별 기본 페이지 전환 종류
