# design 결정 로그 (V#)

디자인 시스템 안의 결정을 기록합니다. 루트 결정(`docs/decisions.md`, D#)이나 브랜드 기반(`docs/identity/README.md`)과 부딪히는 결정은 구현을 멈추고 요청함으로 올립니다.

| ID | 날짜 | 분류 | 결정 | 근거 |
| --- | --- | --- | --- | --- |
| V1 | 2026-10-10 | 색 | 색은 **OKLCH 규칙**으로 만듭니다(고정 명도 단계 + 팔레트별 hue·최대 채도, `tools/palette.py`). 화면과 컴포넌트는 원시 팔레트가 아니라 **의미 역할**만 씁니다 | 사용자 결정 (V0 brainstorming), 시안 `design-v0-brand-palette` |
| V2 | 2026-10-10 | 색 | **브랜드 팔레트(UI)와 오행 팔레트(데이터)를 분리**합니다. 오행은 선명한 견본안(B)이고, 견본·바탕·글자 세 값을 둡니다 | 사용자 결정 (V0 brainstorming), 시안 `design-v0-ohaeng-palette` |
| V3 | 2026-10-10 | 색 | 글자 조합은 **대비 4.5:1 이상**입니다. 좋은 날 배지는 진한 코랄 + 흰 글자(B), 용어 토큰은 굵기 대신 sage-100/700입니다 | 사용자 결정 (V0 brainstorming), 시안 `design-v0-brand-palette` |
| V4 | 2026-10-10 | 범위 | **다크 모드를 MVP에 포함**합니다 | 사용자 결정 (V0 brainstorming) |
| V5 | 2026-10-10 | 그라데이션 | 그라데이션은 `gradient.today` **토큰 하나**로 묶고, 데일리 카드·온보딩·공유 이미지에만 씁니다. 공유 이미지는 라이트로 고정합니다 | 사용자 결정 (V0 brainstorming), 브랜드 기반 "조건부 선택" |
| V6 | 2026-10-10 | 타이포 | 문장은 고운돋움/Zen Maru Gothic 400, UI·데이터는 Pretendard/Pretendard JP, 원국표 한자는 Pretendard JP입니다 | 사용자 결정 (V0 brainstorming) |
| V7 | 2026-10-10 | 로고 | 앱 아이콘은 **세이지 공책 표지 + 반시계 30° 낙관(日)**이고 큰·작은 원형 두 개를 둡니다. 워드마크는 고운돋움 아웃라인입니다 | 사용자 결정 (V0 brainstorming), 시안 `design-v0-logo-diary-seal-v2` |
| V8 | 2026-10-11 | 색 | **색의 의미 규칙**: sage = 나와 내 기록·조작(주 버튼, 선택, 용어 토큰, 일기 쓴 날 표시), coral = 오늘의 좋은 기운(좋은 날·귀인의 날 배지, 캘린더 좋음 칸), neutral = 그 밖의 날과 정보. 좋지 않은 날은 경고색 없이 neutral로 담담하게 보여줍니다 | 사용자 결정 (V1 brainstorming), 시안 `design-v1-color-meaning` |
| V9 | 2026-10-11 | 토큰 | 디자인 토큰은 **DTCG 2025.10 JSON**입니다. 파일은 `primitive` + 색 모드(라이트·다크) + 글자 언어(ko·en / ja)로 나누고, 원본은 생성기(`palette.py`·`tokens.py`)입니다. Dart 코드 생성은 app이 합니다. 계약 버전 1.0.0으로 freeze합니다 | 사용자 결정 (V1 brainstorming), V1 spec §6 |
| V10 | 2026-10-11 | 색 | 날의 성격 배지 4종: 좋은 날(진한 coral 채움) > 귀인의 날(옅은 coral) > 기신의 날(옅은 회색) > 평범한 날(테두리만). 캘린더 길흉은 **날짜 칸 옅게 채우기**(좋음 coral-100, 주의 neutral-100, 보통 없음)이고 점은 일기·일정 표시용으로 남깁니다 | 사용자 결정 (V1 brainstorming), 시안 `design-v1-luck-cell-tint`, `design-v1-day-badges-luck-dots` |
| V11 | 2026-10-11 | 타이포 | V0 범위 값을 단일 값으로 나누고(`label.lg`·`label.md`·`caption.md`·`caption.sm`) `display`, 고정폭 숫자 스타일 2종을 더합니다. 한국어 UI 자간 -2%, 대체 글꼴 순서를 둡니다. 일본어 문장 줄 간격은 카드 1.75 / 본문 1.7입니다 | 사용자 결정 (V1 brainstorming), 시안 `design-v1-ja-line-height` |
| V12 | 2026-10-11 | 간격 | 간격 `space.{2,4,8,12,16,20,24,32,48}`, 반경 `radius.xs 4 / sm 8 / md 12 / lg 20 / xl 28 / full 9999`. 그림자·모션 토큰은 두지 않습니다 | 사용자 결정 (V1 brainstorming), V1 spec §5 |
