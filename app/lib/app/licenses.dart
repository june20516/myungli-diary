import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱에 포함한 글꼴 한 벌. 폴더와 라이선스 파일 위치를 한곳에서 정합니다.
@immutable
class BundledFont {
  /// 글꼴 정보를 만듭니다.
  const new({
    required this.family,
    required this.folder,
    this.licenseFiles = const ['OFL.txt'],
  });

  /// pubspec.yaml과 토큰의 family 이름.
  final String family;

  /// `assets/fonts/` 아래 폴더 이름.
  final String folder;

  /// 폴더 안의 라이선스·고지 파일.
  final List<String> licenseFiles;
}

/// 앱에 포함한 글꼴 전부. pubspec.yaml은 테스트가 이 목록과 대조합니다.
const bundledFonts = <BundledFont>[
  BundledFont(family: 'Gowun Dodum', folder: 'gowun_dodum'),
  BundledFont(family: 'Zen Maru Gothic', folder: 'zen_maru_gothic'),
  BundledFont(
    family: 'Pretendard',
    folder: 'pretendard',
    licenseFiles: ['OFL.txt', 'NOTICE.txt'],
  ),
  BundledFont(
    family: 'Pretendard JP',
    folder: 'pretendard_jp',
    licenseFiles: ['OFL.txt', 'NOTICE.txt'],
  ),
];

/// 글꼴 OFL 전문과 고지를 오픈소스 고지(`showLicensePage`)에 더합니다.
void registerFontLicenses() {
  for (final font in bundledFonts) {
    LicenseRegistry.addLicense(() async* {
      final texts = [
        for (final file in font.licenseFiles)
          await rootBundle.loadString('assets/fonts/${font.folder}/$file'),
      ];
      yield LicenseEntryWithLineBreaks([
        font.family,
      ], texts.join('\n\n-----\n\n'));
    });
  }
}

/// 출생지 도시 자료의 출처 고지(GeoNames, CC BY 4.0, #312).
///
/// 도시 목록은 server가 GeoNames `cities15000`으로 만들고(`server/internal/city`), 앱은 그
/// 이름·시간대를 출생지 검색에 보이므로 오픈소스 고지에 출처·라이선스·가공 사실을 적습니다.
/// 고지 페이지(`showLicensePage`)의 다른 라이선스처럼 원문 언어(영어)로 둡니다.
const String geoNamesNotice = '''
City data (birthplace search): GeoNames, https://www.geonames.org/

Licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0), https://creativecommons.org/licenses/by/4.0/

Changes: uses the cities15000 extract (cities with a population above 15,000, and capitals) and picks Korean, English and Japanese names from the GeoNames alternate names.''';

/// 글꼴 OFL 전문과 고지, 데이터 출처 고지를 오픈소스 고지(`showLicensePage`)에 더합니다(A61).
///
/// 앱을 시작할 때 한 번 부릅니다(`bootstrap`).
void registerAppLicenses() {
  registerFontLicenses();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['GeoNames'], geoNamesNotice);
  });
}
