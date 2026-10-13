import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

void main() {
  test('iOS는 백업에서 뺀 Application Support/Database에 DB를 둡니다', () {
    expect(
      databaseDirectoryPath(
        platform: TargetPlatform.iOS,
        applicationSupport: '/support',
        documents: '/documents',
      ),
      '/support/$iosDatabaseDirectoryName',
    );
    // AppDelegate.swift가 같은 이름의 디렉터리를 백업에서 뺍니다.
    expect(iosDatabaseDirectoryName, 'Database');
  });

  test('iOS가 아니면 drift 기본 위치(문서 디렉터리)입니다', () {
    expect(
      databaseDirectoryPath(
        platform: TargetPlatform.android,
        applicationSupport: '/support',
        documents: '/documents',
      ),
      '/documents',
    );
  });
}
