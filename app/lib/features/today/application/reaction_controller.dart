import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

/// 그날 응답 캐시 키를 찾는 함수. 그 날짜 응답을 캐시에 둔 키가 없으면 null을 돌려줍니다.
///
/// 반응이 성공한 뒤 캐시의 그 슬롯을 고칠 때 씁니다. 기본은 오늘 화면의 응답(`DailyController`)이
/// 보이는 날짜의 키입니다. 달력의 그날 문장·일기가 다른 날짜의 반응을 다루면 이 provider를
/// 바꿔 키를 찾습니다.
final reactionCacheKeyProvider = Provider<String? Function(CalendarDate date)>(
  (ref) =>
      (date) => ref.read(dailyControllerProvider).value?.date == date
      ? ref.read(dailyControllerProvider.notifier).cacheKey
      : null,
);

/// 슬롯 하나의 반응 진행 상태.
final class _Entry {
  new({required this.confirmed}) : wanted = confirmed;

  /// server가 알고 있다고 확인된 마지막 값(처음에는 응답이 준 값).
  bool confirmed;

  /// 사용자가 마지막으로 바란 값.
  bool wanted;

  /// 요청 반복이 돌고 있는지.
  bool sending = false;
}

/// 문장 반응(좋아요)의 낙관적 갱신과 server 맞춤(결정 A25).
///
/// 상태는 "화면에 보일 좋아요 여부"로, 키는 [keyOf](날짜 + 슬롯 id)입니다. 응답이 준 값보다
/// 이 상태가 우선합니다([isLiked]). 총운뿐 아니라 달력의 그날 문장·일기 등 반응할 수 있는
/// 어느 슬롯에도 같은 규칙으로 씁니다.
///
/// * **누르면 바로 바뀝니다.** 상태를 바꾼 뒤 요청합니다.
/// * **마지막 의도만 보냅니다.** 슬롯마다 요청은 한 번에 하나이고, 요청 중에 다시 누르면 의도만
///   기억합니다. 요청이 끝났을 때 의도가 server 상태와 다르면 한 번 더 보내고, 같으면(켬→끔→켬)
///   더 보내지 않습니다.
/// * **실패하면 누르기 전 상태로 돌아갑니다.** 확인된 마지막 값으로 되돌리고 `toggle`이 `AppError`를
///   던집니다. 요청 중에 더 누른 것도 함께 되돌립니다.
/// * **성공하면 캐시도 고칩니다.** 주입된 `DailyRepository`를 통해 그 슬롯의 `reaction`만
///   바꿉니다.
/// * **새 응답이 오면** 요청 중이 아닌 슬롯의 값은 응답을 따르도록 비웁니다.
class ReactionController extends Notifier<Map<String, bool>> {
  final _entries = <String, _Entry>{};

  /// [date]의 [slot]을 가리키는 상태 키.
  static String keyOf(CalendarDate date, String slot) =>
      '${date.toIso()}/$slot';

  /// [state] 위에서 [date]의 [text]가 좋아요 상태로 보일지. 상태에 없으면 응답이 준 값입니다.
  static bool isLiked(
    Map<String, bool> state,
    CalendarDate date,
    SlotText text,
  ) =>
      state[keyOf(date, text.slot)] ??
      text.reaction == SlotTextReactionEnum.like;

  @override
  Map<String, bool> build() {
    // 새 응답은 server의 값이므로, 요청 중이 아닌 슬롯은 그 값을 따릅니다.
    ref.listen(dailyControllerProvider, (previous, next) {
      final view = next.value;
      if (view == null || identical(view, previous?.value)) {
        return;
      }
      _forgetIdle(view.date);
    });
    return const {};
  }

  void _forgetIdle(CalendarDate date) {
    final prefix = '${date.toIso()}/';
    final idle = [
      for (final entry in _entries.entries)
        if (entry.key.startsWith(prefix) && !entry.value.sending) entry.key,
    ];
    if (idle.isEmpty) {
      return;
    }
    _entries.removeWhere((key, _) => idle.contains(key));
    state = {
      for (final entry in state.entries)
        if (!idle.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// [date]의 [text] 반응을 뒤집습니다.
  ///
  /// 이미 같은 슬롯의 요청이 돌고 있으면 의도만 기록하고 바로 끝납니다(그 요청을 부른 쪽이
  /// 끝까지 맞춥니다). 요청을 돌린 쪽에서만 실패가 [AppError]로 올라옵니다.
  Future<void> toggle(SlotText text, {required CalendarDate date}) async {
    final key = keyOf(date, text.slot);
    final entry = _entries.putIfAbsent(
      key,
      () => _Entry(confirmed: text.reaction == SlotTextReactionEnum.like),
    );
    final next = !(state[key] ?? entry.confirmed);
    entry.wanted = next;
    state = {...state, key: next};
    if (entry.sending) {
      return;
    }
    await _sync(key, entry, date: date, slot: text.slot);
  }

  /// 의도와 server 상태가 같아질 때까지 보냅니다.
  Future<void> _sync(
    String key,
    _Entry entry, {
    required CalendarDate date,
    required String slot,
  }) async {
    final repository = ref.read(dailyRepositoryProvider);
    entry.sending = true;
    try {
      while (entry.wanted != entry.confirmed) {
        final target = entry.wanted;
        await repository.setReaction(date, slot: slot, liked: target);
        entry.confirmed = target;
        if (!ref.mounted) {
          return;
        }
        final cacheKey = ref.read(reactionCacheKeyProvider)(date);
        if (cacheKey != null) {
          await writeCacheOrReport(
            () => repository.patchCachedReaction(
              cacheKey,
              slot: slot,
              liked: target,
            ),
            ref.read(crashReporterProvider),
          );
          if (!ref.mounted) {
            return;
          }
        }
      }
    } on AppError {
      entry.wanted = entry.confirmed;
      if (ref.mounted) {
        state = {...state, key: entry.confirmed};
      }
      rethrow;
    } finally {
      entry.sending = false;
    }
  }
}

/// 문장 반응. 화면은 [ReactionController.isLiked]로 보일 값을 읽고
/// [ReactionController.toggle]로 바꿉니다.
final reactionControllerProvider =
    NotifierProvider<ReactionController, Map<String, bool>>(
      ReactionController.new,
    );
