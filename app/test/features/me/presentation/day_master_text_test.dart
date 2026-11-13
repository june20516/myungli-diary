import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/features/me/presentation/saju_chart_tabs.dart';

void main() {
  AppLocalizations l10n(String code) => lookupAppLocalizations(Locale(code));

  group('만세력 기준 줄 일간 표기(W75, sajuChartManseBasisStemSuffix)', () {
    test('ko, en은 사전 천간 이름, ja는 훈독을 괄호에 씁니다', () {
      expect(dayMasterText(l10n('ko'), Stem.gyeong, name: '경금'), '庚(경금)');
      expect(
        dayMasterText(l10n('en'), Stem.gyeong, name: 'Gyeonggeum'),
        '庚 (Gyeonggeum)',
      );
      expect(dayMasterText(l10n('ja'), Stem.gyeong, name: '庚'), '庚（かのえ）');
    });

    test('기준 줄 틀에 넣으면 원고 결과 문장이 됩니다', () {
      final ko = l10n('ko');
      expect(
        ko.sajuChartManseBasis(dayMasterText(ko, Stem.gyeong, name: '경금')),
        '내 일간 庚(경금) 기준',
      );
    });

    test('사전 이름이 없거나 빈 문장이면 이름 자리에 독음을 넘깁니다(A145 ②)', () {
      expect(dayMasterText(l10n('ko'), Stem.gyeong), '庚(경)');
      expect(dayMasterText(l10n('en'), Stem.gyeong, name: ''), '庚 (Gyeong)');
      expect(dayMasterText(l10n('ja'), Stem.gyeong), '庚（かのえ）');
    });
  });
}
