import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:uuid/uuid.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// 이 설치의 id. 없거나 UUID v4 형식이 아니면 새로 만들어 저장합니다.
///
/// 비로그인 요청(`PreviewRequest`·`BirthHourRequest`)의 `installationId`로 쓰며,
/// 기기 플래그에 있어 로그아웃해도 남습니다.
final installationIdProvider = FutureProvider<String>((ref) async {
  final store = ref.watch(deviceFlagsStoreProvider);
  final saved = await store.readString(installationIdKey);
  if (saved != null && _uuidV4.hasMatch(saved)) {
    return saved;
  }
  final created = const Uuid().v4();
  await store.writeString(installationIdKey, value: created);
  return created;
});
