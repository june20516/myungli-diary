import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/presentation/saju_chart_tabs.dart';

/// IA `saju-chart`가 직접 처리하는 상태.
const Set<String> sajuChartHandledStates = {'loading', 'error', 'time-unknown'};

/// IA `saju-chart`의 출구 대상.
const Set<String> sajuChartExits = {
  ScreenIds.explainSheet,
  ScreenIds.evidenceSheet,
};

/// 사주 표의 두 탭(A57).
enum SajuChartTab {
  /// 원국표·오행 분포·용신 판정 근거.
  natal,

  /// 만세력 표·대운·세운 표.
  luck,
}

/// 사주 표(`saju-chart`, evidence 깊이): 내 원국과 운의 흐름을 `segmented` 두 탭으로 보입니다
/// (D16·D18, A57).
///
/// * "원국"은 원국표 → 오행 분포 → 용신 판정 근거(잠기면 흐린 한 줄 + "열기" → 근거 시트, D60),
///   "만세력·대운"은 만세력 표 → 대운·세운 표입니다. 표 데이터는 무료이고 판정 근거·원국 개인
///   해석만 잠깁니다.
/// * 칸의 용어는 풀이 시트를 열고, 그 "근거 보기"가 누른 칸의 원국 개인 해석을 엽니다(A58).
/// * 탭은 화면을 떠났다 와도 기억하지 않고 "원국"부터입니다. 바꾸면 내용이 `appear.seep`으로
///   스밉니다.
/// * 시간 모름이면 위에 안내(`saju-chart.time-unknown.notice`)이고 시주 칸이 빕니다.
/// * 받는 중 skeleton(`loading`), 받지 못하면 오류와 다시 시도(`error`).
class SajuChartScreen extends ConsumerStatefulWidget {
  /// 사주 표 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<SajuChartScreen> createState() => _SajuChartScreenState();
}

class _SajuChartScreenState extends ConsumerState<SajuChartScreen> {
  SajuChartTab _tab = SajuChartTab.natal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chart = ref.watch(chartControllerProvider);
    return Semantics(
      identifier: ScreenIds.sajuChart,
      child: Scaffold(
        key: const ValueKey(ScreenIds.sajuChart),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.sajuChartBarTitle,
                titleIdentifier: SlotIds.sajuChartBarTitle,
                // 스택 바닥(딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s20,
                  Space.s8,
                  Space.s20,
                  Space.s16,
                ),
                child: Segmented<SajuChartTab>(
                  items: [
                    SegmentedItem(SajuChartTab.natal, l10n.sajuChartTabNatal),
                    SegmentedItem(SajuChartTab.luck, l10n.sajuChartTabLuck),
                  ],
                  selected: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                  label: l10n.sajuChartBarTitle,
                ),
              ),
              Expanded(
                child: ScreenStateView<Chart>(
                  value: chart,
                  onRetry: () =>
                      ref.read(chartControllerProvider.notifier).reload(),
                  skeleton: const _SajuChartSkeleton(),
                  dataWithNotice: (value, notice) => _SajuChartBody(
                    chart: value,
                    tab: _tab,
                    offlineNotice: notice,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SajuChartBody extends StatelessWidget {
  const new({
    required this.chart,
    required this.tab,
    required this.offlineNotice,
  });

  final Chart chart;
  final SajuChartTab tab;
  final Widget offlineNotice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        0,
        Space.s20,
        MediaQuery.paddingOf(context).bottom + Space.s32,
      ),
      children: [
        offlineNotice,
        if (chartTimeUnknown(chart))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s16),
            child: NoticeBanner(
              variant: NoticeBannerVariant.timeUnknown,
              message: l10n.sajuChartTimeUnknownNotice,
              identifier: SlotIds.sajuChartTimeUnknownNotice,
            ),
          ),
        SeepOnChange(
          changeKey: tab,
          child: switch (tab) {
            SajuChartTab.natal => SajuChartNatalTab(chart: chart),
            SajuChartTab.luck => SajuChartLuckTab(chart: chart),
          },
        ),
      ],
    );
  }
}

/// 받는 중: 원국표 칸 모양. [ScreenStateView]가 [SkeletonBlock]으로 감싸 지연·숨쉬기·
/// 스크린리더 라벨을 붙입니다.
class _SajuChartSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: Space.s20),
    child: SajuPillarsSkeleton(),
  );
}
