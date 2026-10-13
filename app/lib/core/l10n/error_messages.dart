import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// problem `code`의 ARB 키 이름입니다. `error` 뒤에 code를 lowerCamelCase로
/// 붙입니다. 점(`.`)과 밑줄(`_`)이 단어 경계입니다.
/// 예: `auth.exchange_invalid` → `errorAuthExchangeInvalid`.
String problemMessageKey(String code) {
  final words = code.split(RegExp('[._]')).where((word) => word.isNotEmpty);
  final pascal = words
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();
  return 'error$pascal';
}

/// problem `code` → 사용자 문구 표입니다. 계약 `x-problem-codes`의 code 중
/// 사용자에게 보일 수 있는 것을 모두 담습니다(`test/contract/problem_codes_contract_test.dart`).
/// 키 이름은 [problemMessageKey] 규칙을 따릅니다.
final Map<String, String Function(AppLocalizations)> problemMessages = {
  'request.malformed': (l10n) => l10n.errorRequestMalformed,
  'request.invalid': (l10n) => l10n.errorRequestInvalid,
  'auth.token_expired': (l10n) => l10n.errorAuthTokenExpired,
  'auth.token_invalid': (l10n) => l10n.errorAuthTokenInvalid,
  'auth.refresh_reused': (l10n) => l10n.errorAuthRefreshReused,
  'auth.provider_token_invalid': (l10n) => l10n.errorAuthProviderTokenInvalid,
  'auth.exchange_invalid': (l10n) => l10n.errorAuthExchangeInvalid,
  'app_check.invalid': (l10n) => l10n.errorAppCheckInvalid,
  'consent.required': (l10n) => l10n.errorConsentRequired,
  'preview.used': (l10n) => l10n.errorPreviewUsed,
  'route.not_found': (l10n) => l10n.errorRouteNotFound,
  'diary.not_found': (l10n) => l10n.errorDiaryNotFound,
  'method.not_allowed': (l10n) => l10n.errorMethodNotAllowed,
  'profile.required': (l10n) => l10n.errorProfileRequired,
  'diary.date_taken': (l10n) => l10n.errorDiaryDateTaken,
  'idempotency.in_progress': (l10n) => l10n.errorIdempotencyInProgress,
  'request.too_large': (l10n) => l10n.errorRequestTooLarge,
  'request.unsupported_media_type': (l10n) =>
      l10n.errorRequestUnsupportedMediaType,
  'date.out_of_range': (l10n) => l10n.errorDateOutOfRange,
  'birth.out_of_range': (l10n) => l10n.errorBirthOutOfRange,
  'date.invalid': (l10n) => l10n.errorDateInvalid,
  'request.inconsistent': (l10n) => l10n.errorRequestInconsistent,
  'birth.invalid': (l10n) => l10n.errorBirthInvalid,
  'diary.future_date': (l10n) => l10n.errorDiaryFutureDate,
  'name.empty': (l10n) => l10n.errorNameEmpty,
  'name.too_long': (l10n) => l10n.errorNameTooLong,
  'name.emoji': (l10n) => l10n.errorNameEmoji,
  'name.control': (l10n) => l10n.errorNameControl,
  'name.invalid_char': (l10n) => l10n.errorNameInvalidChar,
  'idempotency.mismatch': (l10n) => l10n.errorIdempotencyMismatch,
  'consent.version_mismatch': (l10n) => l10n.errorConsentVersionMismatch,
  'rate_limited': (l10n) => l10n.errorRateLimited,
  'internal': (l10n) => l10n.errorInternal,
  'not_implemented': (l10n) => l10n.errorNotImplemented,
  'engine.error': (l10n) => l10n.errorEngineError,
  'engine.unavailable': (l10n) => l10n.errorEngineUnavailable,
  'auth.provider_unavailable': (l10n) => l10n.errorAuthProviderUnavailable,
  'billing.provider_unavailable': (l10n) =>
      l10n.errorBillingProviderUnavailable,
  'service.unavailable': (l10n) => l10n.errorServiceUnavailable,
  'engine.timeout': (l10n) => l10n.errorEngineTimeout,
};

/// [error]를 사용자에게 보일 문구로 바꿉니다.
String errorMessage(AppLocalizations l10n, AppError error) {
  return switch (error) {
    OfflineError() => l10n.errorOffline,
    TimeoutError() => l10n.errorTimeout,
    UnexpectedError() => l10n.errorUnexpected,
    ProblemError() => _problemMessage(l10n, error),
  };
}

String _problemMessage(AppLocalizations l10n, ProblemError error) {
  final message = problemMessages[error.code];
  if (message != null) {
    return message(l10n);
  }
  final status = error.status;
  if (status >= 400 && status < 500) {
    return l10n.errorClient;
  }
  if (status >= 500) {
    return l10n.errorServer;
  }
  return l10n.errorUnexpected;
}
