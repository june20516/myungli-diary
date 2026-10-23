import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/features/auth/data/consent_repository.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';

/// 약관 동의 저장소.
final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(ref.watch(restClientProvider)),
);

/// 동의한 버전이 현재 버전과 달라 문서를 다시 받아야 하는 오류인지(422 `consent.version_mismatch`).
bool isConsentVersionMismatch(AppError error) =>
    error is ProblemError && error.code == 'consent.version_mismatch';

/// 동의 화면에 보이고 동의로 보낼 문서입니다.
///
/// `ConsentDocument.document`는 계약의 열린 enum이라 이 app이 모르는 문서가 올 수 있습니다
/// (결정 A66). 모르는 문서는 이름과 문서 주소가 없고 원래 값도 남지 않아 보이지도 보내지도
/// 않습니다. 동의가 필요한데 모르는 문서가 있으면 진입 계산이 먼저 `force-update`로 보내므로
/// (`requiresUnknownConsent`) 이 거름은 화면의 안전망입니다.
List<ConsentDocument> displayableConsents(List<ConsentDocument> documents) => [
  for (final document in documents)
    if (document.document.isKnown) document,
];

/// 약관 동의 화면의 동작입니다(D50).
///
/// 동의에 성공하면, 프로필이 없는 계정(동의 전 내 정보의 `hasProfile == false`)이고 온보딩
/// 입력이 완전할 때(미리보기를 거친 새 계정) **프로필을 먼저 저장한 뒤** 진입을 다시
/// 계산합니다. 먼저 갱신하면 `profileRequired`가 되어 `onboard-call`로 튕기기 때문입니다.
/// 입력이 없으면 진입만 다시 계산해 `onboard-call`로 갑니다. 프로필이 있는 계정(약관 개정
/// 동의)은 입력이 남아 있어도 저장하지 않습니다(`createProfile`은 PUT이라 덮어씀). 남은 입력은
/// 진입이 프로필 있는 갈래가 되면 지워집니다. 이동은 라우터 redirect가 정합니다.
///
/// 처리 중에 다시 부르면 새 요청 없이 진행 중인 시도의 결과를 돌려줍니다.
class ConsentController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<AppError?>? _inFlight;

  /// [documents]에 동의합니다. 동의나 동의 뒤 진입 계산이 실패하면 그 오류를, 아니면 null을
  /// 돌려줍니다.
  ///
  /// 버전이 바뀌었으면(`consent.version_mismatch`) 내 정보를 다시 받아 새 버전을 띄웁니다.
  /// 동의 뒤 프로필 저장이 실패해도 동의는 끝났으므로 진입을 다시 계산해 `onboard-call`로
  /// 보냅니다. 입력 오류면 `onboard-call`이 보일 안내를 남기고, 그 밖의 실패는
  /// `onboard-call`이 한 번 다시 저장합니다.
  Future<AppError?> agree(List<ConsentDocument> documents) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    state = const AsyncLoading();
    final attempt = _attempt(documents).whenComplete(() {
      _inFlight = null;
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    });
    _inFlight = attempt;
    return attempt;
  }

  Future<AppError?> _attempt(List<ConsentDocument> documents) async {
    // 진입 갱신으로 화면이 닫혀 이 controller가 버려져도 끝맺도록 의존성을 먼저 잡아 둡니다.
    final repository = ref.read(consentRepositoryProvider);
    final entry = ref.read(entryStateProvider.notifier);
    final completer = ref.read(onboardingCompleterProvider);
    final notice = ref.read(onboardingRejectionNoticeProvider.notifier);
    // 동의 전 내 정보로 정합니다. 동의 뒤 진입 갱신 전이라도 값이 바뀌지 않게 먼저 잡습니다.
    final needsProfile = ref.read(meProvider)?.hasProfile == false;
    try {
      await repository.agree(documents);
    } on AppError catch (error) {
      if (isConsentVersionMismatch(error)) {
        await entry.refresh();
      }
      return error;
    }
    if (needsProfile && await completer.completeIfReady(notice: notice)) {
      return null;
    }
    // 진입 계산이 실패하면 화면이 머물러 안내하고, 다시 누르면 동의부터 다시 합니다(같은 버전).
    return await entry.refresh();
  }
}

/// 약관 동의 화면 동작. 화면이 보이는 동안만 둡니다.
final AsyncNotifierProvider<ConsentController, void> consentControllerProvider =
    AsyncNotifierProvider.autoDispose<ConsentController, void>(
      ConsentController.new,
    );
