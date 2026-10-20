import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';

/// 화면이 받는 값([AsyncValue])의 상태 판정.
extension AsyncValueLoadState<T> on AsyncValue<T> {
  /// 보일 값 없이 실패로 끝났는지(받는 중이 아님). 줄을 비활성 대신 "다시 받기"로 바꿀 때 씁니다.
  bool get failedWithoutValue => value == null && hasError && !isLoading;
}

/// [provider]를 받지 못할 때마다 이유를 오류 toast로 알립니다. `initState`에서 한 번 부릅니다.
///
/// 받는 중이거나 바로 앞과 같은 오류 객체면 다시 알리지 않습니다(다시 받을 때마다 새 오류면 다시
/// 알림). [AppError]가 아닌 오류는 [UnexpectedError]로 감싸 일반 오류 문구로 보입니다. 구독은
/// 화면이 사라질 때 함께 닫힙니다(`listenManual`).
ProviderSubscription<AsyncValue<T>> listenLoadErrorToast<T>(
  WidgetRef ref,
  BuildContext context,
  ProviderListenable<AsyncValue<T>> provider,
) => ref.listenManual<AsyncValue<T>>(provider, (previous, next) {
  final error = next.error;
  if (next.isLoading ||
      error == null ||
      identical(error, previous?.error) ||
      !context.mounted) {
    return;
  }
  showMyungliToast(
    context,
    errorMessage(
      AppLocalizations.of(context),
      error is AppError ? error : UnexpectedError(error),
    ),
  );
});
