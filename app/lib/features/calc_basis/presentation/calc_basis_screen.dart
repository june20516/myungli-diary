import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/prose_page_body.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/features/calc_basis/application/calc_basis_providers.dart';
import 'package:myungli_diary/features/calc_basis/model/time_basis.dart';

/// 경도 문단 글자(A28). 보정 분의 부호로 빼기·더하기·보정 없음을 고르고, 경도는 0 이상이면
/// 동경, 음수면 서경(절댓값)입니다.
String calcBasisLongitudeText(AppLocalizations l10n, TimeBasis basis) {
  final degrees = longitudeDegreesText(basis.longitude);
  final longitude = basis.longitude >= 0
      ? l10n.calcBasisLongitudeBodyEast(degrees)
      : l10n.calcBasisLongitudeBodyWest(degrees);
  final minutes = basis.correctionMinutes;
  if (minutes > 0) {
    return l10n.calcBasisLongitudeBodyAdd(longitude, minutes);
  }
  if (minutes < 0) {
    return l10n.calcBasisLongitudeBodySubtract(longitude, -minutes);
  }
  return l10n.calcBasisLongitudeBodyNone(longitude);
}

/// 계산 기준(D71): 해석 기준, 다른 유파와 다른 점, 출생 시각 경도 보정, 음력 기준을 안내합니다.
///
/// 로그인 전(출생지 화면)에도 엽니다. 경도 문단은 출생 입력으로 구한 기준([calcBasisTimeBasisProvider])을
/// 쓰고, 기준을 모르거나(null, A29) 구하지 못하거나(오류) 서머타임 기간 출생이면(A31) 그리지
/// 않고 자리도 남기지 않습니다.
/// 불러오는 동안에는 그 자리에 skeleton 한 문단을 두고, 다른 문단은 바로 보입니다. 값이 오면
/// 그때만 `appear.seep`으로 나타나고, 이미 받아 둔 값으로 다시 열면 바로 보입니다.
///
/// IA에 출구가 없어 registry의 `exits`는 기본값(빈 집합)입니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)지만 글자는 설명 본문이라 `sentence-block` `body`로 그립니다.
class CalcBasisScreen extends ConsumerStatefulWidget {
  /// calc-basis 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<CalcBasisScreen> createState() => _CalcBasisScreenState();
}

class _CalcBasisScreenState extends ConsumerState<CalcBasisScreen> {
  /// 경도 문단 자리에 불러오는 중(skeleton)을 보였는지. 보였을 때만 값이 seep으로 나타납니다.
  bool _shownLoading = false;

  @override
  void initState() {
    super.initState();
    // 사용자 눈에는 문단이 빠질 뿐이라 예상 밖 오류는 crash 요약으로 남깁니다
    // (ScreenStateView와 같이 이미 분류된 AppError는 남기지 않습니다).
    ref.listenManual<AsyncValue<TimeBasis?>>(calcBasisTimeBasisProvider, (
      previous,
      next,
    ) {
      final error = next.error;
      // 다시 계산하는 동안(loading)에도 앞 오류가 남아 있으므로 같은 오류는 한 번만 남깁니다.
      if (error == null || identical(error, previous?.error)) return;
      if (error is! AppError) {
        ref
            .read(crashReporterProvider)
            .record(
              CrashSummary.from(error),
              next.stackTrace ?? StackTrace.current,
            );
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final longitude = _longitudeParagraph(
      context,
      ref.watch(calcBasisTimeBasisProvider),
    );
    return Semantics(
      identifier: ScreenIds.calcBasis,
      child: Scaffold(
        key: const ValueKey(ScreenIds.calcBasis),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                title: l10n.calcBasisTitle,
                // 스택 바닥(딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ProsePageBody(
                  paragraphs: [
                    _paragraph(
                      SlotIds.calcBasisConventionBody,
                      l10n.calcBasisConventionBody,
                    ),
                    _paragraph(
                      SlotIds.calcBasisSchoolsBody,
                      l10n.calcBasisSchoolsBody,
                    ),
                    ?longitude,
                    _paragraph(
                      SlotIds.calcBasisLunarBody,
                      l10n.calcBasisLunarBody,
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

  /// 경도 문단. 값이 있으면 문단, 불러오는 중이면 skeleton, 모르거나 오류거나 서머타임 기간
  /// 출생이면 null입니다.
  Widget? _longitudeParagraph(
    BuildContext context,
    AsyncValue<TimeBasis?> basis,
  ) {
    if (basis.hasValue) {
      final value = basis.value;
      if (value == null) return null;
      // 지금 문구는 표준 자오선 기준 보정만 말해 서머타임 출생의 실제 차이와 어긋납니다(A31).
      if (value.daylightSavingMinutes != 0) return null;
      final paragraph = _paragraph(
        SlotIds.calcBasisLongitudeBody,
        calcBasisLongitudeText(AppLocalizations.of(context), value),
      );
      return _shownLoading
          ? SeepPresence(present: true, child: paragraph)
          : paragraph;
    }
    if (basis.hasError) return null;
    // build 중 필드를 바꾸지만 setState는 부르지 않습니다. 한 번 true가 되면 되돌아가지 않는
    // 멱등 단방향 플래그이고, 같은 build가 곧바로 읽는 값이 아니라 "다음에 값이 오면
    // seep으로 나타낼지"만 정해서 이 변경으로 다시 그릴 필요가 없습니다.
    _shownLoading = true;
    // 기본 글줄 셋이 문단 한 개 자리입니다.
    return SkeletonBlock(lineStyle: context.tokens.typography.sentenceBody);
  }
}

/// ARB 문장 하나를 [slotId] 슬롯의 본문 문단으로 그립니다.
Widget _paragraph(String slotId, String text) => SentenceBlock(
  variant: SentenceBlockVariant.body,
  text: RenderedText(segments: [Segment(text: text)]),
  slotId: slotId,
);
