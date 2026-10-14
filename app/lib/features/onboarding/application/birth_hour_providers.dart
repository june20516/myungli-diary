import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/core/storage/installation_id.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/features/onboarding/data/birth_hour_repository.dart';

/// 시진 확인 저장소.
final birthHourRepositoryProvider = Provider<BirthHourRepository>(
  (ref) => BirthHourRepository(
    ref.watch(restClientProvider),
    () => ref.read(installationIdProvider.future),
  ),
);

/// 시진 확인 요청의 키: 생일과 `HH:MM` 시각.
typedef BirthHourQuery = ({BirthDateValue date, String time});

/// 시진 확인 줄에 쓸 시진. 한국 기기가 아니면 요청하지 않고 null입니다(D58).
///
/// 요청이 실패하면(엔진 RPC 전 501 포함) null이라 줄을 그리지 않습니다(A20).
// family 타입 이름이 flutter_riverpod 공개 API에 없어(misc) 추론에 맡깁니다.
// ignore: specify_nonobvious_property_types
final birthHourProvider = FutureProvider.autoDispose
    .family<BirthHour?, BirthHourQuery>((ref, query) async {
      if (!ref.watch(deviceRegionIsKoreaProvider)) {
        return null;
      }
      // 같은 생일·시각은 다시 묻지 않도록 붙들어 둡니다(분당 30회 한도). 실패는 다시 물을 수 있게
      // 놓습니다.
      final link = ref.keepAlive();
      try {
        return await ref
            .watch(birthHourRepositoryProvider)
            .fetch(date: query.date, time: query.time);
      } on AppError {
        link.close();
        return null;
      }
    });
