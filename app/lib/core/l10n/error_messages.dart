import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// problem `code` → 사용자 문구 표입니다. 기반에서는 `not_implemented`만 두고,
/// 각 feature 계획이 자기 code를 더합니다.
final Map<String, String Function(AppLocalizations)> problemMessages = {
  'not_implemented': (l10n) => l10n.errorNotImplemented,
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
