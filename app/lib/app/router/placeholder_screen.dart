import 'package:flutter/material.dart';

/// 화면 본체가 만들어지기 전에 쓰는 자리 표시 화면. 화면 id만 보입니다.
class PlaceholderScreen extends StatelessWidget {
  /// [screenId] 화면의 자리 표시를 만듭니다.
  const new(this.screenId, {super.key});

  /// IA 화면 id.
  final String screenId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: screenId,
      child: Scaffold(
        key: Key(screenId),
        body: Center(child: Text(screenId)),
      ),
    );
  }
}
