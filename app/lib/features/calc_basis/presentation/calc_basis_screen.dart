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

/// IA `calc-basis`의 출구 대상. IA에 출구가 없습니다.
const Set<String> calcBasisExits = <String>{};

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
/// 쓰고, 기준을 모르거나(null, A29) 구하지 못하면(오류) 그리지 않고 자리도 남기지 않습니다.
/// 불러오는 동안에는 그 자리에 skeleton 한 문단을 두고, 다른 문단은 바로 보입니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)지만 글자는 설명 본문이라 `sentence-block` `body`로 그립니다.
class CalcBasisScreen extends ConsumerStatefulWidget {
  /// calc-basis 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<CalcBasisScreen> createState() => _CalcBasisScreenState();
}

class _CalcBasisScreenState extends ConsumerState<CalcBasisScreen> {
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

  /// 경도 문단. 값이 있으면 문단, 불러오는 중이면 skeleton, 모르거나 오류면 null입니다.
  Widget? _longitudeParagraph(
    BuildContext context,
    AsyncValue<TimeBasis?> basis,
  ) {
    if (basis.hasValue) {
      final value = basis.value;
      if (value == null) return null;
      return SeepPresence(
        present: true,
        child: _paragraph(
          SlotIds.calcBasisLongitudeBody,
          calcBasisLongitudeText(AppLocalizations.of(context), value),
        ),
      );
    }
    if (basis.hasError) return null;
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
