import 'package:flutter/material.dart';

void main() {
  runApp(const MyungliApp());
}

/// 앱 루트 위젯입니다. 이후 task에서 라우터 기반으로 바뀝니다.
class MyungliApp extends StatelessWidget {
  /// 앱 루트 위젯을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SizedBox.shrink());
  }
}
