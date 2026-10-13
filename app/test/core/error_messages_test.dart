import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

ProblemError _problem(String code, int status) => ProblemError(
  code: code,
  status: status,
  fieldErrors: const [],
  traceId: 't1',
);

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  group('errorMessage', () {
    test('OfflineError는 errorOffline', () {
      expect(errorMessage(ko, const OfflineError()), ko.errorOffline);
    });

    test('TimeoutError는 errorTimeout', () {
      expect(errorMessage(ko, const TimeoutError()), ko.errorTimeout);
    });

    test('UnexpectedError는 errorUnexpected', () {
      expect(errorMessage(ko, const UnexpectedError('x')), ko.errorUnexpected);
    });

    test('not_implemented는 errorNotImplemented', () {
      expect(
        errorMessage(ko, _problem('not_implemented', 501)),
        ko.errorNotImplemented,
      );
    });

    test('표에 없는 code는 status 대역 문구', () {
      expect(errorMessage(ko, _problem('unknown.x', 409)), ko.errorClient);
      expect(errorMessage(ko, _problem('unknown.x', 400)), ko.errorClient);
      expect(errorMessage(ko, _problem('unknown.x', 499)), ko.errorClient);
      expect(errorMessage(ko, _problem('unknown.x', 500)), ko.errorServer);
      expect(errorMessage(ko, _problem('unknown.x', 503)), ko.errorServer);
    });

    test('대역 밖 status는 errorUnexpected', () {
      expect(errorMessage(ko, _problem('unknown.x', 0)), ko.errorUnexpected);
      expect(errorMessage(ko, _problem('unknown.x', 302)), ko.errorUnexpected);
    });

    test('영어 로케일에서도 같은 표를 쓴다', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        errorMessage(en, _problem('not_implemented', 501)),
        en.errorNotImplemented,
      );
    });
  });
}
