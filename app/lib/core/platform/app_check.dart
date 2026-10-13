import 'package:myungli_diary/core/api/interceptors/common_headers.dart';

/// Firebase App Check. 토큰을 내는 쪽은 [AppCheckTokenSource]입니다.
abstract interface class AppCheck implements AppCheckTokenSource;
