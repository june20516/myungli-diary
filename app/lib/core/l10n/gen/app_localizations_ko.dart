// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get errorOffline => '인터넷에 연결되어 있지 않아요.';

  @override
  String get errorTimeout => '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorClient => '요청을 처리하지 못했어요.';

  @override
  String get errorServer => '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorUnexpected => '예기치 못한 문제가 생겼어요.';

  @override
  String get errorNotImplemented => '아직 준비 중이에요.';

  @override
  String get actionRetry => '다시 시도';

  @override
  String traceIdLabel(String traceId) {
    return '문의 번호 $traceId';
  }
}
