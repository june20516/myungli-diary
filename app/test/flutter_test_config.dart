import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// golden 기준 이미지는 Linux에서만 만들고 비교합니다.
///
/// 글꼴 래스터화가 플랫폼마다 달라 macOS에서 만든 이미지는 CI와 어긋납니다.
/// `goldenTest`(test/support/golden.dart)는 Linux가 아니면 건너뛰고, 이 비교기는
/// 그 도우미를 거치지 않은 golden 비교가 Linux 밖에서 돌면 실패시킵니다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 기준 이미지는 테스트 파일 위치와 관계없이 test/goldens에 모읍니다.
  final goldens = Uri.file('${Directory.current.path}/test/goldens/');
  goldenFileComparator = _LinuxOnlyComparator(goldens);
  await testMain();
}

/// Linux가 아니면 비교·갱신을 거부하는 [LocalFileComparator].
class _LinuxOnlyComparator extends LocalFileComparator {
  new(Uri basedir) : super(basedir.resolve('_'));

  static const String _message =
      'golden은 Linux에서만 비교합니다. tool/goldens_linux.sh로 갱신하세요.';

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) {
    if (!Platform.isLinux) throw StateError(_message);
    return super.compare(imageBytes, golden);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    if (!Platform.isLinux) throw StateError(_message);
    return super.update(golden, imageBytes);
  }
}
