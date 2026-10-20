// 계약의 열린 enum에 표시(x-myungli-open-enum)를 단 생성용 계약 사본을 JSON으로 씁니다. 결정 A66.
// 실행: dart run tool/mark_open_enums.dart <출력 JSON 경로> (보통 tool/gen_api.sh가 부름)

import 'dart:convert';
import 'dart:io';

import 'common/open_enums.dart';
import 'common/openapi_spec.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('사용법: dart run tool/mark_open_enums.dart <출력 JSON 경로>');
    exitCode = 64;
    return;
  }
  final marked = markOpenEnums(loadOpenApi());
  File(args.single).writeAsStringSync(jsonEncode(marked));
}
