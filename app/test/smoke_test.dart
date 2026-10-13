import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/main.dart';

void main() {
  testWidgets('앱이 뜬다', (tester) async {
    await tester.pumpWidget(const MyungliApp());

    expect(find.byType(MyungliApp), findsOneWidget);
  });
}
