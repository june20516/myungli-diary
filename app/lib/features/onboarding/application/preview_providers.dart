import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/preview.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/installation_id.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/preview_repository.dart';

/// 미리보기 저장소.
final previewRepositoryProvider = Provider<PreviewRepository>(
  (ref) => PreviewRepository(
    ref.watch(restClientProvider),
    () => ref.read(installationIdProvider.future),
    () => ref.read(deviceTimezoneNameProvider.future),
  ),
);

/// 받은 미리보기와 그때의 출생 입력. 설치당 한 번뿐인 응답을 같은 입력으로 다시 열 때(다시 입력 뒤
/// 바꾸지 않고 돌아온 경우) 다시 묻지 않고 쓰기 위해 붙들어 둡니다.
final class _PreviewMemo {
  Birth? birth;
  Preview? preview;
}

final _previewMemoProvider = Provider<_PreviewMemo>((ref) {
  final memo = _PreviewMemo();
  // 로그아웃하면 입력과 함께 비웁니다(온보딩 입력과 같게).
  final signedOut = ref
      .watch(tokenStoreProvider)
      .events
      .where((event) => event == AuthEvent.signedOut)
      .listen(
        (_) => memo
          ..birth = null
          ..preview = null,
      );
  ref.onDispose(signedOut.cancel);
  return memo;
});

/// 온보딩 입력으로 받는 첫 풀이. 같은 입력으로는 한 번만 요청합니다(설치당 1회 한도).
///
/// 실패는 붙들지 않아 다시 불러 오면 다시 요청합니다.
// autoDispose provider 타입 이름이 flutter_riverpod 공개 API에 없어(misc) 추론에 맡깁니다.
// ignore: specify_nonobvious_property_types
final previewProvider = FutureProvider.autoDispose<Preview>((ref) async {
  final draft = await ref.watch(onboardingDraftProvider.future);
  final deviceRegionIsKorea = ref.watch(deviceRegionIsKoreaProvider);
  final birth = draft.toBirth(deviceRegionIsKorea: deviceRegionIsKorea);
  final memo = ref.read(_previewMemoProvider);
  final saved = memo.preview;
  if (saved != null && memo.birth == birth) {
    return saved;
  }
  final preview = await ref
      .watch(previewRepositoryProvider)
      .create(draft: draft, deviceRegionIsKorea: deviceRegionIsKorea);
  memo
    ..birth = birth
    ..preview = preview;
  return preview;
}, retry: (_, _) => null);
