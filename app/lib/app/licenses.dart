import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱에 포함한 글꼴과 OFL.txt 위치.
const _fontLicenses = <({String name, String asset})>[
  (name: 'Gowun Dodum', asset: 'assets/fonts/gowun_dodum/OFL.txt'),
  (name: 'Zen Maru Gothic', asset: 'assets/fonts/zen_maru_gothic/OFL.txt'),
  (name: 'Pretendard', asset: 'assets/fonts/pretendard/OFL.txt'),
  (name: 'Pretendard JP', asset: 'assets/fonts/pretendard_jp/OFL.txt'),
];

/// 글꼴 OFL 전문을 오픈소스 고지(`showLicensePage`)에 더합니다.
void registerFontLicenses() {
  for (final font in _fontLicenses) {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(font.asset);
      yield LicenseEntryWithLineBreaks([font.name], text);
    });
  }
}
