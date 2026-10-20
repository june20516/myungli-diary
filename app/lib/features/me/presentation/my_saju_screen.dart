import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/notice_text.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';
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

/// 나의 사주(`me` 탭 루트, `my-saju`): 일간과 용신·행운 색으로 내 원국을 보입니다(D16, A55).
///
/// * 위에서부터 시간 모름 배너(`Chart.notices`의 `time_unknown`), 일간 칸과 이름(용어 →
///   `explain-sheet` `stem.<값>`), 용신 줄(사전 `role.yongsin` 이름 + 오행 용어 →
///   `explain-sheet` `element.<값>`)과 행운 색 칩(`lucky-card` `color`, 누르면 오행 뜻),
///   "근거 보기"(`depth-link` `block` → `saju-chart`)입니다.
/// * 문장 슬롯(`my-saju.ilgan.head`·`ilgan.body`·`yongsin.body`)은 계약 `Chart`에 필드가
///   생기면 그립니다(server #329). 그 전에는 자리를 비웁니다.
/// * 받는 중 skeleton(`loading`), 받지 못하면 오류와 다시 시도(`error`).
/// * 앱 바 톱니는 `settings`, 아래 광고 배너는 탭 틀이 그립니다(D53).
class MySajuScreen extends ConsumerWidget {
  /// my-saju 화면을 만듭니다.
  const new({super.key});

  /// 앱 바 톱니(설정).
  static const Key settingsKey = ValueKey('my-saju.settings');

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
                  skeleton: const Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.s20,
                      Space.s8,
                      Space.s20,
                      0,
                    ),
                    child: SkeletonBlock(lines: 4),
                  ),
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

class _MySajuBody extends ConsumerWidget {
  const new({required this.chart, required this.offlineNotice});

  final Chart chart;
  final Widget offlineNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final names = ref.watch(glossaryProvider).value;
    final sheets = ref.read(depthSheetsProvider);
    void explain(String termId) => sheets.openExplain(context, termId: termId);

    final timeUnknown = chart.notices
        .where((n) => n.code == NoticeCode.timeUnknown)
        .map(noticeTextOf)
        .nonNulls
        .firstOrNull;
    final dayStem = chart.pillars.day.stem;
    final dayStemName = names?.valueName('stem', dayStem.value);
    final yongsin = chart.yongsin.yongsin;
    final yongsinName = names?.valueName('element', yongsin.value);
    final roleName = names?.valueName('role', 'yongsin');
    final colorName = names?.valueName('color', yongsin.value);
    final colorMeaning = names?.meaningOf('element.${yongsin.value}');

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
        Center(
          child: SizedBox(
            width: 88,
            child: OhaengCell(
              element: stemElement(dayStem),
              hanja: stemHanja(dayStem),
              reading: dayStemName,
            ),
          ),
        ),
        if (dayStemName != null) ...[
          const SizedBox(height: Space.s8),
          Center(
            child: TermToken(
              label: dayStemName,
              variant: TermTokenVariant.inline,
              textStyle: tokens.typography.subtitle,
              onTap: () => explain('stem.${dayStem.value}'),
            ),
          ),
        ],
        const SizedBox(height: Space.s24),
        if (roleName != null && yongsinName != null)
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
        if (colorName != null && colorMeaning != null) ...[
          const SizedBox(height: Space.s12),
          LuckyCardRow(
            items: [_colorItem(l10n, names!, chart, colorName, colorMeaning)],
          ),
        ],
        DepthLink(
          variant: DepthLinkVariant.block,
          label: l10n.depthLinkEvidence,
          onTap: () => context.push<void>(pathOf(ScreenIds.sajuChart)),
        ),
      ],
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
