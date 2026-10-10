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
