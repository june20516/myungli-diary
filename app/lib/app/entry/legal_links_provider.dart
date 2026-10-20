import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/legal_links.dart';

/// 법적 문서 페이지가 아는 언어(`?lang=`, 계약 `LegalLinks`).
const Set<String> legalDocumentLanguages = {'ko', 'en', 'ja'};

/// 법적 문서 주소 [address]에 화면 언어 [languageCode]를 `lang`으로 붙입니다(D80).
///
/// 주소에는 query가 없다는 것이 계약이지만, 있더라도 지우지 않고 `lang`만 더합니다. 페이지가
/// 모르는 언어면 붙이지 않아 server 기본 언어(`en`)로 열립니다.
Uri legalDocumentUri(String address, String languageCode) {
  final uri = Uri.parse(address);
  if (!legalDocumentLanguages.contains(languageCode)) {
    return uri;
  }
  return uri.replace(
    queryParameters: {...uri.queryParameters, 'lang': languageCode},
  );
}

/// 이용약관·개인정보 처리방침 주소(`AppConfig.legal`, D80·A61). 주소의 출처는 이 provider 하나입니다.
///
/// 진입 계산이 받은 `getAppConfig`가 있으면 다시 부르지 않고 그 값입니다. 없으면(진입 계산 전에
/// 끝난 상태 등) `getAppConfig`를 불러 받습니다. 받지 못하면 [AppError]이고 저절로 다시 받지
/// 않으며, 화면이 `invalidate`로 다시 받습니다. 화면을 떠나면 버려 다음에 열 때 다시 시도합니다.
final FutureProvider<LegalLinks> legalLinksProvider =
    FutureProvider.autoDispose<LegalLinks>((ref) async {
      final fromEntry = ref.watch(entryAppConfigProvider)?.legal;
      if (fromEntry != null) {
        return fromEntry;
      }
      try {
        final response = await ref.read(restClientProvider).getAppConfig();
        final config = response.data;
        if (config == null) {
          throw UnexpectedError(StateError('빈 응답'));
        }
        return config.legal;
      } on DioException catch (error) {
        throw appErrorFrom(error);
      }
    }, retry: (_, _) => null);
