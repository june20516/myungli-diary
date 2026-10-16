import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/onboarding/application/city_providers.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';

/// IA `birthplace`의 출구 대상. 온보딩은 `preview`, 로그인한 새 계정은 프로필을 저장하고
/// `notify-ask`(D68), 수정 모드는 `profile-edit`·`settings`
/// (값을 `pop`으로 돌려주므로 화면이 직접 이동하지 않습니다). 두 모드 모두 계산 기준 링크로
/// `calc-basis`를 쌓습니다(D71).
const Set<String> birthplaceExits = {
  ScreenIds.calcBasis,
  ScreenIds.preview,
  ScreenIds.notifyAsk,
  ScreenIds.profileEdit,
  ScreenIds.settings,
};

/// IA `birthplace`가 직접 처리하는 상태.
const Set<String> birthplaceHandledStates = {'loading', 'empty', 'error'};

/// 입력이 멈춘 것으로 보고 검색하기까지 기다리는 시간.
const Duration _searchDebounce = Duration(milliseconds: 300);

/// 온보딩 다섯째 단계: 한국 밖 기기에서 출생 도시를 골라 출생 시간대를 정합니다(D29).
///
/// 글자 입력이 300ms 멈추면 검색하고, 도시를 누르면 곧바로 다음으로 갑니다(건너뛰기 출구는
/// 없습니다). 검색칸 위에는 한국 표준 소개와 계산 기준 링크가 있습니다(D71). 링크는
/// `calc-basis`를 쌓으므로 돌아오면 검색어와 결과가 그대로입니다.
///
/// 온보딩에서는 초안에 담은 뒤, 로그인했고 프로필이 없는 계정
/// ([finishesWithoutPreviewProvider])이면 미리보기를 건너뛰고 마무리 동작
/// ([onboardingFinishProvider])을 부르고, 아니면 `preview`로 갑니다. 저장이 입력 오류(422)면
/// `onboard-call`로 돌아가 고치게 합니다. 수정 모드(`?mode=edit`)에서는 고른
/// [City]를 `pop`으로 돌려줍니다. 사본의 출생지는 도시 id뿐이라 이름을 모르므로 수정 모드도
/// 빈 검색칸에서 시작합니다.
class BirthplaceScreen extends ConsumerWidget {
  /// birthplace 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = onboardingStepModeOf(GoRouterState.of(context));
    return Semantics(
      identifier: ScreenIds.birthplace,
      child: Scaffold(
        key: const ValueKey(ScreenIds.birthplace),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                // 스택 바닥(갈래의 첫 화면, 딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                title: '',
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(child: _BirthplaceForm(mode: mode)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthplaceForm extends ConsumerStatefulWidget {
  const new({required this.mode});

  final OnboardingStepMode mode;

  @override
  ConsumerState<_BirthplaceForm> createState() => _BirthplaceFormState();
}

class _BirthplaceFormState extends ConsumerState<_BirthplaceForm> {
  /// 검색 결과. 검색어가 비면 null이라 결과 자리가 없습니다.
  AsyncValue<List<City>>? _results;
  Timer? _debounce;

  /// 마지막으로 보낸(또는 보낼) 검색어. 다시 시도가 같은 질의를 보냅니다.
  String _query = '';

  /// 요청과 비우기마다 올라가는 번호. 늦게 온 이전 응답을 버리는 기준입니다.
  int _generation = 0;
  bool _saving = false;

  /// 저장을 기다리는 동안 고른 도시 id. 그 줄 끝에 점 숨쉬기가 나옵니다(`city-search` saving).
  String? _savingCityId;

  /// 저장이 실패했을 때 입력칸 아래 오류 줄(`input-step` error)로 보일 오류. 다른 도시를
  /// 고르거나 검색어를 바꾸면 사라집니다.
  AppError? _saveError;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (_saveError != null) setState(() => _saveError = null);
    _query = value.trim();
    if (_query.isEmpty) {
      _generation++;
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(_searchDebounce, _search);
  }

  /// 지금 검색어로 검색합니다. 받는 동안 이전 줄이 있으면 그대로 둡니다.
  Future<void> _search() async {
    final generation = ++_generation;
    final query = _query;
    final previous = _results;
    setState(
      () => _results = previous == null
          ? const AsyncLoading<List<City>>()
          // 이전 줄을 붙인 loading은 provider가 만드는 상태라 내부 API를 씁니다
          // (city-search 테스트와 같은 방식).
          // ignore: invalid_use_of_internal_member
          : const AsyncLoading<List<City>>().copyWithPrevious(previous),
    );
    final AsyncValue<List<City>> result;
    try {
      result = AsyncData(
        await ref
            .read(cityRepositoryProvider)
            .search(query, language: ref.read(appLanguageProvider)),
      );
    } on Object catch (error, stack) {
      if (!mounted || generation != _generation) return;
      setState(() => _results = AsyncError(error, stack));
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() => _results = result);
  }

  /// 계산 기준 화면을 쌓습니다. 도시를 고른 뒤 처리 중이면 이동하지 않습니다.
  void _openCalcBasis() {
    if (_saving) return;
    unawaited(context.push<void>(pathOf(ScreenIds.calcBasis)));
  }

  Future<void> _onSelected(City city) async {
    if (_saving) return;
    if (widget.mode == OnboardingStepMode.edit) {
      context.pop(city);
      return;
    }
    // 아래 버튼이 없어(`bottomAction.omitWhen`) 고른 줄 끝의 점이 처리 중을 보입니다
    // (`city-search` saving). 실패하면 아래 finally에서 점이 사라집니다.
    setState(() {
      _saving = true;
      _savingCityId = city.id;
      _saveError = null;
    });
    try {
      await ref
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(city: city));
      if (!mounted) return;
      if (ref.read(finishesWithoutPreviewProvider)) {
        await ref.read(onboardingFinishProvider)();
      } else {
        await context.push<void>(pathOf(ScreenIds.preview));
      }
    } on OnboardingInputRejected catch (rejected) {
      // 입력 오류는 첫 단계(onboard-call)부터 고칩니다(약관 동의 직후 저장과 같은 동작).
      if (!mounted) return;
      returnToOnboardCallWith(context, ref, rejected.error);
    } on Object catch (error) {
      // 마무리 동작이 실패해도 미처리 비동기 오류로 남기지 않고 오류 줄로 안내합니다
      // (`city-search` 규칙: 저장이 실패하면 input-step 오류 줄로 돌아간다).
      if (!mounted) return;
      setState(() => _saveError = onboardingErrorOf(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savingCityId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = widget.mode == OnboardingStepMode.edit;
    final saveError = _saveError;
    // 도시를 누르면 곧바로 다음으로 가므로 아래 버튼을 두지 않습니다(`bottomAction.omitWhen`).
    return InputStep.selectToAdvance(
      screenId: ScreenIds.birthplace,
      variant: edit ? InputStepVariant.standalone : InputStepVariant.onboarding,
      step: edit ? null : 5,
      stepCount: edit ? null : ref.watch(onboardingStepCountProvider),
      question: l10n.birthplaceQuestionHead,
      preface: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: SlotIds.birthplaceStandardNote,
            child: Text(
              l10n.birthplaceStandardNote,
              key: const ValueKey(SlotIds.birthplaceStandardNote),
              style: InputStep.helpStyleOf(context),
            ),
          ),
          // 소개 바로 아래 space.12(depth-link navigate가 위 여백을 가짐, 결정 V32).
          DepthLink(
            variant: DepthLinkVariant.navigate,
            label: l10n.birthplaceStandardLink,
            slotId: SlotIds.birthplaceStandardLink,
            onTap: _openCalcBasis,
          ),
        ],
      ),
      input: CitySearch(
        label: l10n.birthplaceSearchLabel,
        hint: l10n.birthplaceSearchHint,
        hintIdentifier: SlotIds.birthplaceSearchHint,
        emptyIdentifier: SlotIds.birthplaceEmptyBody,
        onQueryChanged: _onQueryChanged,
        results: _results,
        onSelected: _onSelected,
        emptyBody: l10n.birthplaceEmptyBody,
        onRetry: _search,
        savingCityId: _savingCityId,
      ),
      error: saveError == null ? null : errorMessage(l10n, saveError),
      help: l10n.birthplaceWhyBody,
      helpIdentifier: SlotIds.birthplaceWhyBody,
    );
  }
}
