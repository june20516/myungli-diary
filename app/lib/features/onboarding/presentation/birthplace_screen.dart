import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/features/onboarding/application/city_providers.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';

/// IA `birthplace`의 출구 대상. 온보딩은 `preview`, 수정 모드는 `profile-edit`·`settings`
/// (값을 `pop`으로 돌려주므로 화면이 직접 이동하지 않습니다).
const Set<String> birthplaceExits = {
  ScreenIds.preview,
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
/// 없습니다). 온보딩에서는 초안에 담은 뒤 세션이 없으면 `preview`로, 있으면 미리보기를 건너뛰고
/// 마무리 동작([onboardingFinishProvider])을 부릅니다. 수정 모드(`?mode=edit`)에서는 고른
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
              const MyungliAppBar.inner(title: ''),
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
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

  Future<void> _onSelected(City city) async {
    if (_saving) return;
    if (widget.mode == OnboardingStepMode.edit) {
      context.pop(city);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(city: city));
      if (!mounted) return;
      if (ref.read(meProvider) != null) {
        await ref.read(onboardingFinishProvider)();
      } else {
        await context.push<void>(pathOf(ScreenIds.preview));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = widget.mode == OnboardingStepMode.edit;
    return InputStep(
      screenId: ScreenIds.birthplace,
      variant: edit ? InputStepVariant.standalone : InputStepVariant.onboarding,
      step: edit ? null : 5,
      stepCount: edit ? null : ref.watch(onboardingStepCountProvider),
      question: l10n.birthplaceQuestionHead,
      input: CitySearch(
        label: l10n.birthplaceSearchLabel,
        hint: l10n.birthplaceSearchHint,
        onQueryChanged: _onQueryChanged,
        results: _results,
        onSelected: _onSelected,
        emptyBody: l10n.birthplaceEmptyBody,
        onRetry: _search,
      ),
      help: l10n.birthplaceWhyBody,
      helpIdentifier: SlotIds.birthplaceWhyBody,
      actionLabel: edit ? l10n.onboardingSave : l10n.onboardingNext,
      actionLoading: _saving,
      // 도시를 누르면 곧바로 다음으로 가므로 눌러서 쓰는 버튼은 아닙니다(건너뛰기 출구 없음).
      onAction: null,
    );
  }
}
