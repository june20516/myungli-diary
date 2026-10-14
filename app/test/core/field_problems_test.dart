import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/field_problems.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';

ProblemError _problem(List<FieldProblem> errors) => ProblemError(
  code: 'request.inconsistent',
  status: 422,
  fieldErrors: errors,
  traceId: 't',
);

void main() {
  test('아래 위치의 오류가 그 칸에 붙는다', () {
    const item = FieldProblem('/birth/time/value', 'required_by_status');
    final error = _problem([item]);
    expect(fieldProblemAt(error, profilePointers.birthTime), item);
    expect(fieldProblemAt(error, profilePointers.birthDate), isNull);
  });

  test('같은 위치도 붙고 이름만 앞부분이 같은 위치는 붙지 않는다', () {
    const exact = FieldProblem('/birth/time', 'x');
    const other = FieldProblem('/birth/timezone', 'y');
    expect(fieldProblemAt(_problem([other, exact]), '/birth/time'), exact);
    expect(fieldProblemAt(_problem([other]), '/birth/time'), isNull);
  });

  test('ProblemError가 아니면 null이다', () {
    expect(fieldProblemAt(const OfflineError(), '/honorific'), isNull);
  });

  test('호칭 상한은 ko·ja 10, en 20이다', () {
    expect(honorificMaxLength(Language.ko), 10);
    expect(honorificMaxLength(Language.ja), 10);
    expect(honorificMaxLength(Language.en), 20);
  });
}
