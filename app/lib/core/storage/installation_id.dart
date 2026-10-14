import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:uuid/uuid.dart';

/// 이 설치의 id. 없으면 UUID v4를 만들어 저장합니다.
///
/// 비로그인 요청(`PreviewRequest`·`BirthHourRequest`)의 `installationId`로 쓰며,
/// 기기 플래그에 있어 로그아웃해도 남습니다.
final installationIdProvider = FutureProvider<String>((ref) async {
  final store = ref.watch(deviceFlagsStoreProvider);
  final saved = await store.readString(installationIdKey);
  if (saved != null) {
    return saved;
  }
  final created = const Uuid().v4();
  await store.writeString(installationIdKey, value: created);
  return created;
});
