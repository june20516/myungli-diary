import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registerAppLicenses는 글꼴과 GeoNames(CC BY 4.0) 고지를 더합니다(A61, #312)',
    () async {
      registerAppLicenses();
      final entries = await LicenseRegistry.licenses.toList();

      final geonames = entries.where((e) => e.packages.contains('GeoNames'));
      expect(geonames, hasLength(1));
      final text = geonames.single.paragraphs.map((p) => p.text).join('\n');
      // server 도시 자료의 출처 표기(server/internal/city/README.md)를 그대로 씁니다.
      expect(text, contains('GeoNames, https://www.geonames.org/'));
      expect(text, contains('CC BY 4.0'));
      expect(text, contains('https://creativecommons.org/licenses/by/4.0/'));

      for (final font in bundledFonts) {
        expect(
          entries.where((e) => e.packages.contains(font.family)),
          hasLength(1),
          reason: font.family,
        );
      }
    },
  );
}
