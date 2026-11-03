# release R8 규칙(#728). Flutter gradle plugin이 이 파일이 있으면 release에 자동으로 더합니다
# (FlutterPlugin.kt, Flutter 기본 규칙과 라이브러리 consumer 규칙 다음).

# Room은 생성된 `<DB>_Impl`을 reflection으로 기본 생성자를 불러 만듭니다.
# 광고 SDK(play-services-ads)가 들여오는 room-runtime 2.2.5의 consumer 규칙은
# `-keep class * extends androidx.room.RoomDatabase`로 클래스 이름만 지키고,
# AGP 8 이후 기본인 R8 full mode는 이 규칙에서 기본 생성자를 남기지 않습니다.
# 그러면 WorkManager가 앱 시작(androidx.startup) 때 WorkDatabase_Impl을 만들지 못하고 종료합니다.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
