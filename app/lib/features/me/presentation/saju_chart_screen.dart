import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/birth_format.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/seep_on_change.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/birth_info_row.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';
import 'package:myungli_diary/features/me/presentation/chart_text.dart';
import 'package:myungli_diary/features/me/presentation/saju_chart_tabs.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

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
///   "만세력과 대운"은 만세력 표 → 대운·세운 표입니다. 표 데이터는 무료이고 판정 근거·원국 개인
///   해석만 잠깁니다.
/// * 칸의 용어는 풀이 시트를 열고, 그 "근거 보기"가 누른 칸의 원국 개인 해석을 엽니다(A58).
/// * 탭은 화면을 떠났다 와도 기억하지 않고 "원국"부터입니다(나 탭 "대운 전체"만 `?tab=luck`으로
///   만세력과 대운 탭에서 엽니다, A117). 바꾸면 내용이 `appear.seep`으로
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
  /// 처음 탭은 경로 query(`?tab=luck`, A117)가 정합니다. 없거나 다른 값이면 원국입니다.
  late SajuChartTab _tab =
      GoRouterState.of(context).uri.queryParameters[sajuChartTabQuery] ==
          sajuChartTabLuck
      ? SajuChartTab.luck
      : SajuChartTab.natal;

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
              Expanded(
                // 머리와 탭 고르기는 탭 내용과 함께 스크롤합니다. 작은 화면과 큰 글자에서 본문
                // 높이를 지키고, 탭을 바꿔도 머리는 같은 모양입니다(controller 결정 A).
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + Space.s32,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        Space.s20,
                        Space.s8,
                        Space.s20,
                        0,
                      ),
                      child: _SajuChartHead(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.s20,
                        Space.s16,
                        Space.s20,
                        Space.s16,
                      ),
                      child: Segmented<SajuChartTab>(
                        items: [
                          SegmentedItem(
                            SajuChartTab.natal,
                            l10n.sajuChartTabNatal,
                          ),
                          SegmentedItem(
                            SajuChartTab.luck,
                            l10n.sajuChartTabLuck,
                          ),
                        ],
                        selected: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                        label: l10n.sajuChartBarTitle,
                      ),
                    ),
                    ScreenStateView<Chart>(
                      value: chart,
                      onRetry: () =>
                          ref.read(chartControllerProvider.notifier).reload(),
                      skeleton: _SajuChartSkeleton(tab: _tab),
                      dataWithNotice: (value, notice) => _SajuChartBody(
                        chart: value,
                        tab: _tab,
                        offlineNotice: notice,
                      ),
                    ),
                  ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}

/// 받는 중: 고른 탭의 배치대로 섹션 머리(ui 슬롯이라 바로)와 컴포넌트 뼈. [ScreenStateView]가
/// [SkeletonBlock]으로 감싸 지연, 숨쉬기, 스크린리더 라벨을 붙입니다.
class _SajuChartSkeleton extends StatelessWidget {
  const new({required this.tab});

  final SajuChartTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s20),
      child: switch (tab) {
        SajuChartTab.natal => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l10n.sajuChartPillarsTitle,
              description: l10n.sajuChartPillarsDesc,
            ),
            const SizedBox(height: SectionHeader.contentGap),
            const SajuChartCard(child: SajuPillarsSkeleton()),
          ],
        ),
        SajuChartTab.luck => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ManseTable(
              basis: '',
              basisGlyph: '',
              table: BandTable(
                columns: [
                  for (final column in ChartColumn.values)
                    BandColumn(
                      header: column.header(l10n),
                      isDay: column == ChartColumn.day,
                    ),
                ],
                bandLabels: {
                  BandKind.hiddenStems: l10n.manseRowHiddenStems,
                  BandKind.twelveStages: l10n.manseRowTwelveStages,
                  BandKind.shinsal: l10n.manseRowShinsal,
                },
                onBandTap: (_) {},
                meLabel: l10n.sajuTagMe,
                emptyLabel: l10n.bandTableEmptyCell,
                tableLabel: l10n.manseTableLabel,
                loading: true,
              ),
            ),
            const SizedBox(height: SectionHeader.sectionGap),
            DaeunTable.loading(
              daeunTitle: l10n.sajuChartDaeunTitle,
              daeunDescription: l10n.sajuChartDaeunDesc,
              seunTitle: l10n.sajuChartSeunTitle,
              seunDescription: l10n.sajuChartSeunDesc,
            ),
          ],
        ),
      },
    );
  }
}

/// 두 탭 공통 머리(`saju-chart.head.title`, `birth-info-row`, A118): "<호칭>님의 사주"와 출생
/// 정보 줄.
///
/// 호칭과 출생 정보는 `Chart`에 없어 프로필([profileProvider])에서 읽습니다. 시진은 계산
/// 기준(야자시 등)을 따른 원국의 시주 지지이고, 원국이 시간 모름이면 시간 모름 알약입니다.
/// 프로필을 못 읽었거나 시간을 아는데 원국이 없으면 그 줄만 뼈로 둡니다(화면의 나머지는 그대로).
/// 뼈는 받는 중에만 숨쉬고, 받지 못했으면(오류) 멈춘 뼈입니다.
class _SajuChartHead extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final profileState = ref.watch(profileProvider);
    final chartState = ref.watch(chartControllerProvider);
    final profile = profileState.value;
    // 머리 제목 서체: 계약(saju.json, IA)에 값이 없어 app이 고른 type.title입니다.
    final titleStyle = tokens.typography.title.copyWith(
      color: tokens.colors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile == null)
          SkeletonBlock(
            child: FractionallySizedBox(
              widthFactor: _titleSkeletonWidth,
              alignment: AlignmentDirectional.centerStart,
              child: SkeletonBone(
                height: titleStyle.fontSize! * titleStyle.height!,
                borderRadius: Radii.xs,
                animated: profileState.isLoading,
              ),
            ),
          )
        else
          Semantics(
            identifier: SlotIds.sajuChartHeadTitle,
            header: true,
            child: Text(
              l10n.sajuChartHeadTitle(profile.honorific),
              style: titleStyle,
            ),
          ),
        const SizedBox(height: Space.s8),
        _birthRow(l10n, profile, chartState.value) ??
            SkeletonBlock(
              child: BirthInfoRow.skeleton(
                animated: profileState.isLoading || chartState.isLoading,
              ),
            ),
      ],
    );
  }

  // 제목 뼈 폭(제목 한 줄의 절반 정도). 계약 값이 없는 화면 배치 값입니다.
  static const double _titleSkeletonWidth = 0.5;

  /// 출생 정보 줄. 그릴 값이 모자라면 null입니다.
  static Widget? _birthRow(
    AppLocalizations l10n,
    Profile? profile,
    Chart? chart,
  ) {
    if (profile == null) return null;
    final birth = profile.birth;
    final calendarTag = birthCalendarTag(
      l10n,
      calendar: birth.calendar,
      isLeapMonth: birth.isLeapMonth,
    );
    final date = formatBirthDayNumeric(
      l10n.localeName,
      birth.date.year,
      birth.date.month,
      birth.date.day,
    );
    final gender = genderLabel(l10n, birth.gender);
    final clock = birth.time.value;
    if (birth.time.status != BirthTimeStatusEnum.known ||
        clock == null ||
        (chart != null && chartTimeUnknown(chart))) {
      return BirthInfoRow(
        calendarTag: calendarTag,
        date: date,
        gender: gender,
        timeUnknown: true,
      );
    }
    final hourBranch = chart?.pillars.hour?.branch;
    if (hourBranch == null) return null;
    return BirthInfoRow(
      calendarTag: calendarTag,
      date: date,
      gender: gender,
      hourGlyph: branchHanja(hourBranch),
      hourName: l10n.birthInfoHour(branchName(l10n, hourBranch)),
      time: formatBirthClock(l10n.localeName, clock),
    );
  }
}
