import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/daeun_period.dart';
import 'package:myungli_diary/core/api/gen/model/diary_stats.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/seun_year.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/notice_text.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/diary/diary_summary.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/application/diary_stats_provider.dart';
import 'package:myungli_diary/features/me/application/luck_years.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';
import 'package:myungli_diary/features/me/presentation/chart_text.dart';
import 'package:myungli_diary/features/me/presentation/natal_card.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// IA `my-saju`가 직접 처리하는 상태.
const Set<String> mySajuHandledStates = {'loading', 'error', 'time-unknown'};

/// IA `my-saju`의 출구 대상.
const Set<String> mySajuExits = {
  ScreenIds.sajuChart,
  ScreenIds.explainSheet,
  ScreenIds.settings,
};

const AppGlyph _gear = AppGlyph(
  light: PhosphorIconsLight.gear,
  regular: PhosphorIconsRegular.gear,
);

/// 이미 보고한 회고 태그 사전 빈칸(용어 id). 화면을 다시 그려도 같은 빈칸을 거듭 보고하지 않게
/// 앱 실행 동안 한 번만 보고합니다(A112).
final _reportedRecordTagGapsProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// 나의 사주(`me` 탭 루트, `my-saju`): 내 원국을 다섯 섹션으로 보입니다(D16, V76, V77).
///
/// * 위에서부터 시간 모름 배너(`Chart.notices`의 `time_unknown`), 그리고 섹션 다섯입니다.
///   사주 원국(`mySajuChartTitle`, 오른쪽 "사주 표" → `saju-chart`, 네 기둥과 오행 분포) →
///   사주 성향 풀이(일간 문장 둘) → 나를 돕는 기운(용신, 행운 색 칩, 용신 문장) →
///   올해와 지금("대운 전체" → `saju-chart` 만세력과 대운 탭, 지금 대운과 올해 세운
///   `luck-pillar` `compact`) → 명리일기 회고(`diary-summary`).
/// * 문장 슬롯은 `Chart.ilganHead`·`ilganBody`·`yongsinSummary`입니다. 필드가 없거나 빈 문장이면
///   그 자리를 그리지 않습니다. 문장 안 용어와 십성 칩은 풀이 시트를 엽니다.
/// * 회고는 따로 받아(A119) 실패해도 회고 카드 자리에만 오류와 다시 시도가 뜨고 다른 섹션은
///   그대로입니다.
/// * 받는 중 skeleton(`loading`), 받지 못하면 오류와 다시 시도(`error`).
/// * 앱 바 톱니는 `settings`, 아래 광고 배너는 탭 틀이 그립니다(D53).
class MySajuScreen extends ConsumerWidget {
  /// my-saju 화면을 만듭니다.
  const new({super.key});

  /// 앱 바 톱니(설정).
  static const Key settingsKey = ValueKey('my-saju.settings');

  /// 회고 카드 자리 오류의 "다시 시도" 영역을 찾는 테스트용 키.
  static const Key recordErrorKey = ValueKey('my-saju.record-error');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chart = ref.watch(chartControllerProvider);
    return Semantics(
      identifier: ScreenIds.mySaju,
      child: Scaffold(
        key: const ValueKey(ScreenIds.mySaju),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MyungliAppBar.tabRoot(
                title: l10n.mySajuBarTitle,
                titleIdentifier: SlotIds.mySajuBarTitle,
                actions: [
                  AppBarAction(
                    key: settingsKey,
                    icon: _gear,
                    semanticLabel: l10n.settingsBarTitle,
                    onPressed: () =>
                        context.push<void>(pathOf(ScreenIds.settings)),
                  ),
                ],
              ),
              Expanded(
                child: ScreenStateView<Chart>(
                  value: chart,
                  onRetry: () =>
                      ref.read(chartControllerProvider.notifier).reload(),
                  skeleton: const _MySajuSkeleton(),
                  dataWithNotice: (value, notice) =>
                      _MySajuBody(chart: value, offlineNotice: notice),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 섹션 안 카드 바탕(`bg.sheet`, `radius.lg`, 안쪽 `space.16`).
class _SectionCard extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.colors.bgSheet,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
      ),
      child: Padding(padding: const EdgeInsets.all(Space.s16), child: child),
    ),
  );
}

class _MySajuBody extends ConsumerWidget {
  const new({required this.chart, required this.offlineNotice});

  final Chart chart;
  final Widget offlineNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final names = ref.watch(glossaryProvider).value;
    final sheets = ref.read(depthSheetsProvider);
    void explain(String termId) =>
        sheets.openExplain(context, ExplainTerm(termId));

    // 판정은 사주 표와 같은 [chartTimeUnknown]이고, 문구는 이 화면에 ui 슬롯이 없어 server 안내
    // 문장입니다(문장이 없으면 배너도 없음).
    final timeUnknown = chartTimeUnknown(chart)
        ? chart.notices
              .where((n) => n.code == NoticeCode.timeUnknown)
              .map(noticeTextOf)
              .nonNulls
              .firstOrNull
        : null;
    final text = ChartText(context, names, sheets);
    final yongsin = _YongsinSection(
      chart: chart,
      explain: explain,
      explainLucky: (item) => sheets.openExplain(
        context,
        ExplainLucky(title: item.name, body: item.explain),
      ),
    );
    final ilgan = _IlganSection(chart: chart, explain: explain);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        Space.s8,
        Space.s20,
        MediaQuery.paddingOf(context).bottom + Space.s32,
      ),
      children: [
        offlineNotice,
        if (timeUnknown != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s16),
            child: NoticeBanner(
              variant: NoticeBannerVariant.timeUnknown,
              message: timeUnknown,
            ),
          ),
        SectionHeader(
          title: l10n.mySajuChartTitle,
          titleIdentifier: SlotIds.mySajuChartTitle,
          trailing: SectionHeaderLink(
            label: l10n.mySajuChartLink,
            onTap: () => context.push<void>(pathOf(ScreenIds.sajuChart)),
          ),
        ),
        const SizedBox(height: SectionHeader.contentGap),
        _SectionCard(
          child: NatalCard(chart: chart, onTermTap: text.openTerm),
        ),
        const SizedBox(height: SectionHeader.sectionGap),
        SectionHeader(
          title: l10n.mySajuIlganTitle,
          titleIdentifier: SlotIds.mySajuIlganTitle,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        ilgan,
        const SizedBox(height: SectionHeader.sectionGap),
        SectionHeader(
          title: l10n.mySajuYongsinTitle,
          titleIdentifier: SlotIds.mySajuYongsinTitle,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        yongsin,
        const SizedBox(height: SectionHeader.sectionGap),
        SectionHeader(
          title: l10n.mySajuFlowTitle,
          titleIdentifier: SlotIds.mySajuFlowTitle,
          trailing: SectionHeaderLink(
            label: l10n.mySajuFlowLink,
            onTap: () => context.push<void>(sajuChartLuckPath()),
          ),
        ),
        const SizedBox(height: SectionHeader.contentGap),
        _FlowCard(chart: chart, text: text),
        const SizedBox(height: SectionHeader.sectionGap),
        SectionHeader(
          title: l10n.mySajuRecordTitle,
          titleIdentifier: SlotIds.mySajuRecordTitle,
        ),
        const SizedBox(height: SectionHeader.contentGap),
        const _RecordSection(),
      ],
    );
  }
}

/// 문장 필드가 있고 비어 있지 않으면 그 문장, 아니면 null입니다.
RenderedText? _textOf(SlotText? sentence) {
  final text = sentence?.text;
  return text == null || isBlankText(text) ? null : text;
}

/// 사주 성향 풀이: 일간 소개 첫 문장(`card`)과 이어지는 문장(`body`). 둘 다 없으면 그리지 않습니다.
class _IlganSection extends StatelessWidget {
  const new({required this.chart, required this.explain});

  final Chart chart;
  final void Function(String termId) explain;

  @override
  Widget build(BuildContext context) {
    final head = _textOf(chart.ilganHead);
    final body = _textOf(chart.ilganBody);
    if (head == null && body == null) return const SizedBox.shrink();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (head != null)
            SentenceBlock(
              variant: SentenceBlockVariant.card,
              text: head,
              slotId: SlotIds.mySajuIlganHead,
              onTerm: explain,
            ),
          if (head != null && body != null)
            const SizedBox(height: SectionHeader.contentGap),
          if (body != null)
            SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: body,
              slotId: SlotIds.mySajuIlganBody,
              onTerm: explain,
            ),
        ],
      ),
    );
  }
}

/// 나를 돕는 기운: 용신 줄(역할 이름 + 오행 용어), 행운 색 칩, 용신 문장.
class _YongsinSection extends ConsumerWidget {
  const new({
    required this.chart,
    required this.explain,
    required this.explainLucky,
  });

  final Chart chart;
  final void Function(String termId) explain;

  /// 행운 색 칩을 눌렀을 때 설명 시트를 엽니다(시트가 닫히면 끝나는 Future).
  final Future<void> Function(LuckyItem item) explainLucky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final names = ref.watch(glossaryProvider).value;
    final yongsin = chart.yongsin.yongsin;
    final yongsinName = names?.valueName('element', yongsin.value);
    final roleName = names?.valueName('role', 'yongsin');
    final colorName = names?.valueName('color', yongsin.value);
    final colorMeaning = names?.meaningOf('element.${yongsin.value}');
    final summary = _textOf(chart.yongsinSummary);
    final hasLine = roleName != null && yongsinName != null;
    final hasColor = colorName != null && colorMeaning != null;
    if (!hasLine && !hasColor && summary == null) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasLine)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.s8,
              children: [
                Text(
                  roleName,
                  style: tokens.typography.bodyUi.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
                TermToken(
                  label: yongsinName,
                  variant: TermTokenVariant.inline,
                  textStyle: tokens.typography.bodyUi,
                  onTap: () => explain('element.${yongsin.value}'),
                ),
              ],
            ),
          if (hasColor) ...[
            if (hasLine) const SizedBox(height: SectionHeader.contentGap),
            LuckyCardRow(
              items: [_colorItem(l10n, names!, chart, colorName, colorMeaning)],
              onOpen: explainLucky,
            ),
          ],
          if (summary != null) ...[
            if (hasLine || hasColor)
              const SizedBox(height: SectionHeader.contentGap),
            SentenceBlock(
              variant: SentenceBlockVariant.body,
              text: summary,
              slotId: SlotIds.mySajuYongsinBody,
              onTerm: explain,
            ),
          ],
        ],
      ),
    );
  }

  static LuckyItem _colorItem(
    AppLocalizations l10n,
    GlossaryNames names,
    Chart chart,
    String colorName,
    RenderedText meaning,
  ) => LuckyItem(
    variant: LuckyCardVariant.color,
    name: l10n.todayLuckyColorName,
    value: colorName,
    explain: meaning,
    element: chart.yongsin.yongsin,
  );
}

/// 올해와 지금: 지금 대운과 올해 세운 `luck-pillar` `compact` 두 줄(줄 사이 `space.16`).
///
/// 지금 대운은 기기 오늘의 연도 기준이고(첫 대운 전이면 줄이 없음), 올해 세운이 응답에 없으면 그
/// 줄이 없습니다. 둘 다 없으면 카드를 그리지 않습니다. 나이는 한국식 나이입니다(core C22).
class _FlowCard extends ConsumerWidget {
  const new({required this.chart, required this.text});

  final Chart chart;
  final ChartText text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = text.l10n;
    final thisYear = ref.watch(todayProvider).year;
    final periods = chart.daeun.periods;
    final daeunIndex = currentDaeunIndex(chart.daeun, thisYear: thisYear);
    final daeun = daeunIndex == null ? null : periods[daeunIndex];
    final seun = chart.seun.where((year) => year.year == thisYear).firstOrNull;
    final seunIndex = seun == null ? null : chart.seun.indexOf(seun);
    if (daeun == null && seun == null) return const SizedBox.shrink();
    // 세운의 나이는 응답에 없어 대운의 (시작 연도, 한국식 나이)에서 출생 연도를 거꾸로 셉니다.
    final birthYear = periods.isEmpty
        ? null
        : periods.first.startYear - periods.first.startAgeKorean + 1;

    Widget gap() => const SizedBox(height: Space.s16);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (daeun != null)
            LuckPillar.compact(
              pillar: _ganjiOf(daeun.pillar),
              tagLabel: l10n.daeunTagNow,
              kindLabel: l10n.sajuChartDaeunTitle,
              onKindTap: () => _explainKind(
                context,
                title: l10n.sajuChartDaeunTitle,
                body: l10n.sajuChartDaeunDesc,
              ),
              period: _daeunPeriod(l10n, daeun),
              tenGods: [
                ?text.luckLabel(
                  'ten_god',
                  daeun.stemTenGod.value,
                  PersonalReadingKey(
                    kind: PersonalReadingKindEnum
                        .PersonalReadingKindDaeunStemTenGod,
                    index: daeunIndex,
                  ),
                ),
                ?text.luckLabel(
                  'ten_god',
                  daeun.branchTenGod.value,
                  PersonalReadingKey(
                    kind: PersonalReadingKindEnum
                        .PersonalReadingKindDaeunBranchTenGod,
                    index: daeunIndex,
                  ),
                ),
              ],
              // 낭독에는 누를 수 있는 칩 낱말(십성, 대운)을 넣지 않습니다. 칩이 따로 button입니다.
              semanticLabel: text.join([
                l10n.daeunTagNow,
                _daeunPeriod(l10n, daeun),
                text.stemText(daeun.pillar.stem),
                text.branchText(daeun.pillar.branch),
              ]),
            ),
          if (daeun != null && seun != null) gap(),
          if (seun != null)
            LuckPillar.compact(
              pillar: _ganjiOf(seun.pillar),
              tagLabel: l10n.seunTagThisYear,
              kindLabel: l10n.sajuChartSeunTitle,
              onKindTap: () => _explainKind(
                context,
                title: l10n.sajuChartSeunTitle,
                body: l10n.sajuChartSeunDesc,
              ),
              period: _seunPeriod(l10n, seun, birthYear),
              tenGods: [
                ?text.luckLabel(
                  'ten_god',
                  seun.tenGod.value,
                  PersonalReadingKey(
                    kind: PersonalReadingKindEnum.PersonalReadingKindSeunTenGod,
                    index: seunIndex,
                  ),
                ),
              ],
              semanticLabel: text.join([
                l10n.seunTagThisYear,
                _seunPeriod(l10n, seun, birthYear),
                text.stemText(seun.pillar.stem),
                text.branchText(seun.pillar.branch),
              ]),
            ),
        ],
      ),
    );
  }

  void _explainKind(
    BuildContext context, {
    required String title,
    required String body,
  }) =>
      text.sheets.openExplain(context, ExplainUiText(title: title, body: body));

  static LuckGanji _ganjiOf(Pillar pillar) => LuckGanji(
    stemElement: stemElement(pillar.stem),
    stemHanja: stemHanja(pillar.stem),
    branchElement: branchElement(pillar.branch),
    branchHanja: branchHanja(pillar.branch),
  );

  /// 대운 기간 줄: 한국식 나이 범위와 연도 범위(한 대운은 10년).
  static String _daeunPeriod(AppLocalizations l10n, DaeunPeriod period) {
    final age = l10n.luckDaeunAgeRange(
      period.startAgeKorean,
      period.startAgeKorean + _daeunYears - 1,
    );
    final years = l10n.luckDaeunYearRange(
      period.startYear,
      period.startYear + _daeunYears - 1,
    );
    return '$age $years';
  }

  /// 세운 기간 줄: 연도와 그해 한국식 나이(출생 연도를 모르면 연도만).
  static String _seunPeriod(
    AppLocalizations l10n,
    SeunYear seun,
    int? birthYear,
  ) {
    final year = l10n.luckSeunYear(seun.year);
    if (birthYear == null) return year;
    return '$year ${l10n.luckSeunAge(seun.year - birthYear + 1)}';
  }

  /// 대운 한 칸의 햇수.
  static const int _daeunYears = 10;
}

/// 명리일기 회고: 집계를 받는 동안 뼈, 받으면 `diary-summary`, 실패하면 이 자리에만 오류와 다시 시도.
class _RecordSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(diaryStatsProvider);
    final names = ref.watch(glossaryProvider).value;
    final sheets = ref.read(depthSheetsProvider);
    final value = stats.value;
    if (value != null) {
      String? tagNameOf(Tag tag) => names?.valueName('tag', tag.key);
      // 이름 사전을 받은 뒤에만 빈칸을 셉니다(받기 전에는 모든 태그가 이름이 없어 보임). 사전을
      // 끝내 못 받으면(names == null) 태그가 모두 숨고 아무것도 기록하지 않습니다. 그 실패는
      // 사전 provider와 화면 상태가 따로 다루고, 태그 수만큼 기록이 쏟아지지 않게 합니다.
      if (names != null) _reportSkippedTags(ref, value, tagNameOf);
      return DiarySummary(
        stats: value,
        tagNameOf: tagNameOf,
        onTagTap: (tag) => sheets.openExplain(
          context,
          ExplainTerm('tag.${tag.key}'),
          head: HanjaTag(
            glyph: HanjaGlyphs.forTagKey(tag.key)!,
            label: tagNameOf(tag)!,
          ),
          diaryLinkTag: tag.key,
        ),
      );
    }
    if (stats.hasError) {
      final error = stats.error;
      return KeyedSubtree(
        key: MySajuScreen.recordErrorKey,
        child: ErrorState(
          error: error is AppError
              ? error
              : UnexpectedError(error ?? 'unknown'),
          onRetry: () => ref.invalidate(diaryStatsProvider),
        ),
      );
    }
    return SkeletonBlock(child: DiarySummary.skeleton());
  }

  void _reportSkippedTags(
    WidgetRef ref,
    DiaryStats stats,
    DiaryTagNameOf tagNameOf,
  ) {
    final reported = ref.read(_reportedRecordTagGapsProvider);
    for (final key in DiarySummary.skippedTagKeys(stats, tagNameOf)) {
      final termId = 'tag.$key';
      if (reported.add(termId)) {
        ref
            .read(crashReporterProvider)
            .record(
              CrashSummary.from(MissingDictionaryEntry(termId)),
              StackTrace.current,
            );
      }
    }
  }
}

/// 받는 중: 다섯 섹션을 실제 배치(화면 좌우 [Space.s20], 제목 아래 [SectionHeader.contentGap],
/// 섹션 사이 [SectionHeader.sectionGap])대로 놓습니다(V66). 큰 글자에서 화면보다 길어도 넘치지
/// 않게 잘라 둡니다.
class _MySajuSkeleton extends StatelessWidget {
  const new();

  /// 용신 줄(역할 이름 + 용신 이름) 뼈 폭 비율.
  static const double _yongsinLineWidthFactor = 0.4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.s20, Space.s8, Space.s20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: l10n.mySajuChartTitle),
          const SizedBox(height: SectionHeader.contentGap),
          const SajuPillarsSkeleton(),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.mySajuIlganTitle),
          const SizedBox(height: SectionHeader.contentGap),
          SentenceBlock.skeleton(variant: SentenceBlockVariant.card, index: 1),
          const SizedBox(height: SectionHeader.contentGap),
          SentenceBlock.skeleton(variant: SentenceBlockVariant.body, index: 3),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.mySajuYongsinTitle),
          const SizedBox(height: SectionHeader.contentGap),
          SkeletonTextLines(
            style: context.tokens.typography.bodyUi,
            widthFactor: _yongsinLineWidthFactor,
            index: 5,
          ),
          const SizedBox(height: SectionHeader.contentGap),
          LuckyCardRow.skeleton(count: 1, index: 6),
          const SizedBox(height: SectionHeader.contentGap),
          SentenceBlock.skeleton(variant: SentenceBlockVariant.body, index: 7),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.mySajuFlowTitle),
          const SizedBox(height: SectionHeader.contentGap),
          LuckPillar.skeleton(index: 8),
          const SizedBox(height: Space.s16),
          LuckPillar.skeleton(index: 11),
          const SizedBox(height: SectionHeader.sectionGap),
          SectionHeader(title: l10n.mySajuRecordTitle),
          const SizedBox(height: SectionHeader.contentGap),
          DiarySummary.skeleton(),
        ],
      ),
    );
  }
}
