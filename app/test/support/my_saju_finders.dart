import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';

final _ko = AppLocalizationsKo();

/// [of] 안 섹션 제목의 오른쪽 링크 중 [label] 글자의 눌림 대상.
Finder sectionLinkTarget({required Finder of, required String label}) =>
    find.descendant(
      of: find.descendant(of: of, matching: find.byType(SectionHeader)),
      matching: find.text(label),
    );

/// 나 탭 "사주 원국" 섹션의 "사주 표" 링크(→ 사주 표 원국 탭).
Finder mySajuChartLink({required Finder of}) =>
    sectionLinkTarget(of: of, label: _ko.mySajuChartLink);

/// 나 탭 "올해와 지금" 섹션의 "대운 전체" 링크(→ 사주 표 만세력과 대운 탭).
Finder mySajuFlowLink({required Finder of}) =>
    sectionLinkTarget(of: of, label: _ko.mySajuFlowLink);
