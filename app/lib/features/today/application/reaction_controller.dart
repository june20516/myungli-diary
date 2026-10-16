import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/reaction_epoch.dart';
import 'package:myungli_diary/features/today/data/daily_repository.dart';

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
  new({required this.date, required this.slot, required this.confirmed})
    : wanted = confirmed;

  final CalendarDate date;
  final String slot;

  /// 가장 최근에 확인한 server 값(처음에는 응답이 준 값, 요청이 확인되거나 새 응답이 오면 갱신).
  bool confirmed;

  /// 사용자가 마지막으로 바란 값.
  bool wanted;

  /// [confirmed]를 이 슬롯의 요청으로 확인한 때의 확인 세대. 요청으로 확인한 적이 없으면 0입니다.
  int confirmedEpoch = 0;

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
/// * **실패하면 누르기 전 상태로 돌아갑니다.** 가장 최근에 확인한 값(요청 중에 새 응답이 왔으면 그
///   응답 값)으로 되돌리고 `toggle`이 `AppError`를 던집니다. 요청 중에 더 누른 것도 함께 되돌립니다.
/// * **성공하면 캐시도 고칩니다.** 주입된 `DailyRepository`를 통해 그 슬롯의 `reaction`만
///   바꿉니다.
/// * **새 응답은 확인 세대로 가립니다.** 반응이 확인될 때마다 세대([ReactionEpoch])가 오르고 응답은
///   받기 시작한 세대를 들고 옵니다. 응답이 시작한 뒤에 확인된 슬롯은 응답이 그 확인을 모를 수
///   있으므로 값을 유지하고 캐시를 다시 고칩니다. 그 앞에 확인했거나 확인한 적 없는 슬롯은 응답
///   값을 따릅니다(다른 기기의 변경 반영).
/// * **항목의 수명은 그 날짜를 보이는 화면의 응답이 정합니다.** 오늘 응답은 오늘 날짜 항목만
///   맞추고, 오늘 화면의 날짜가 바뀌면(자정) 막 떠난 날짜의 항목을 지웁니다. 그 순간 요청
///   중인 항목은 요청이 끝날 때(성공·실패 모두) 지웁니다. 달력·일기 등 다른 날짜의 항목은
///   오늘 응답이 다시 와도 건드리지 않습니다.
class ReactionController extends Notifier<Map<String, bool>> {
  final _entries = <String, _Entry>{};

  /// 오늘 화면이 마지막으로 반영한 응답의 날짜. 날짜가 바뀌면 이 날짜가 "막 떠난 날짜"입니다.
  CalendarDate? _shownDate;

  /// 오늘 화면이 떠난 날짜의 항목 가운데, 그때 요청 중이라 지우지 못한 키. 요청이 끝나면 지웁니다.
  final _pendingDrop = <String>{};

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
    // 오늘 응답이 먼저 와 있었으면 그 날짜부터 봅니다(자정에 떠난 날짜를 알기 위해).
    _shownDate = ref.read(dailyControllerProvider).value?.date;
    ref.listen(dailyControllerProvider, (previous, next) {
      final view = next.value;
      if (view == null || identical(view, previous?.value)) {
        return;
      }
      _applyResponse(view);
    });
    return const {};
  }

  /// 오늘 응답 [view]를 슬롯별로 반영합니다.
  ///
  /// [view] 날짜의 항목만 맞춥니다. 오늘 화면의 날짜가 바뀌었으면(자정) 막 떠난 날짜
  /// ([_shownDate])의 항목을 지우고, 요청 중인 항목은 [_pendingDrop]에 두어 요청이 끝날 때
  /// 지웁니다. 그 밖의 날짜(달력·일기가 다루는 날)의
  /// 항목은 그 화면의 응답이 맞추므로 여기서는 건드리지 않습니다. 같은 날의 다시 받기·조용히
  /// 다시 받기·캐시 → server 교체에서는 날짜가 그대로라 다른 날짜 항목이 남습니다.
  void _applyResponse(DailyView view) {
    final left = _shownDate != view.date ? _shownDate : null;
    _shownDate = view.date;
    final dropped = <String>[];
    for (final MapEntry(:key, value: entry) in _entries.entries) {
      if (entry.date != view.date) {
        if (entry.date == left) {
          if (entry.sending) {
            _pendingDrop.add(key);
          } else {
            dropped.add(key);
          }
        }
        continue;
      }
      final afterFetchStart = entry.confirmedEpoch > view.reactionEpoch;
      if (afterFetchStart) {
        // 응답이 이 확인을 모를 수 있습니다. 값을 유지하고, 응답이 덮었을 캐시를 다시 고칩니다.
        if (!entry.sending) {
          unawaited(
            _patchCache(entry.date, entry.slot, liked: entry.confirmed),
          );
        }
        continue;
      }
      if (entry.sending) {
        // 요청 중에 온 server 응답이 가장 최근에 확인한 값입니다. 요청이 실패하면 여기로 돌아갑니다.
        // 캐시 값은 server가 확인한 것이 아니므로 쓰지 않습니다.
        if (!view.fromCache) {
          entry.confirmed =
              likedReactionOf(view.daily, entry.slot) ?? entry.confirmed;
        }
      } else {
        dropped.add(key);
      }
    }
    _drop(dropped);
  }

  /// [keys] 항목과 상태 키를 지웁니다.
  void _drop(Iterable<String> keys) {
    final gone = keys.toSet();
    if (gone.isEmpty) {
      return;
    }
    _entries.removeWhere((key, _) => gone.contains(key));
    state = {
      for (final entry in state.entries)
        if (!gone.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// [date]의 그날 캐시에서 [slot]의 반응을 [liked]로 고칩니다.
  ///
  /// 캐시 키를 찾지 못하거나 쓰기에 실패해도 던지지 않고 보고만 합니다(캐시는 보조 저장소).
  Future<void> _patchCache(
    CalendarDate date,
    String slot, {
    required bool liked,
  }) => writeCacheOrReport(() async {
    final cacheKey = ref.read(reactionCacheKeyProvider)(date);
    if (cacheKey == null) {
      return;
    }
    await ref
        .read(dailyRepositoryProvider)
        .patchCachedReaction(cacheKey, slot: slot, liked: liked);
  }, ref.read(crashReporterProvider));

  /// [date]의 [text] 반응을 뒤집습니다.
  ///
  /// 이미 같은 슬롯의 요청이 돌고 있으면 의도만 기록하고 바로 끝납니다(그 요청을 부른 쪽이
  /// 끝까지 맞춥니다). 요청을 돌린 쪽에서만 실패가 [AppError]로 올라옵니다. API 밖의 예외도
  /// 진단만 보고하고 `UnexpectedError`로 바꿔 올립니다.
  Future<void> toggle(SlotText text, {required CalendarDate date}) async {
    final key = keyOf(date, text.slot);
    final entry = _entries.putIfAbsent(
      key,
      () => _Entry(
        date: date,
        slot: text.slot,
        confirmed: text.reaction == SlotTextReactionEnum.like,
      ),
    );
    final next = !(state[key] ?? entry.confirmed);
    entry.wanted = next;
    state = {...state, key: next};
    if (entry.sending) {
      return;
    }
    await _sync(key, entry);
  }

  /// 의도와 server 상태가 같아질 때까지 보냅니다.
  Future<void> _sync(String key, _Entry entry) async {
    final repository = ref.read(dailyRepositoryProvider);
    entry.sending = true;
    try {
      while (entry.wanted != entry.confirmed) {
        final target = entry.wanted;
        await repository.setReaction(
          entry.date,
          slot: entry.slot,
          liked: target,
        );
        entry.confirmed = target;
        if (!ref.mounted) {
          return;
        }
        entry.confirmedEpoch = ref.read(reactionEpochProvider).advance();
        await _patchCache(entry.date, entry.slot, liked: target);
        if (!ref.mounted) {
          return;
        }
      }
    } on Object catch (error, stack) {
      entry.wanted = entry.confirmed;
      if (ref.mounted) {
        state = {...state, key: entry.confirmed};
      }
      if (error is AppError) {
        rethrow;
      }
      if (ref.mounted) {
        ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
      }
      Error.throwWithStackTrace(UnexpectedError(error), stack);
    } finally {
      entry.sending = false;
      // 요청 중에 오늘 화면이 이 날짜를 떠났으면 이제 지웁니다(성공·실패 모두).
      if (_pendingDrop.remove(key) && ref.mounted) {
        _drop([key]);
      }
    }
  }
}

/// 문장 반응. 화면은 [ReactionController.isLiked]로 보일 값을 읽고
/// [ReactionController.toggle]로 바꿉니다.
final reactionControllerProvider =
    NotifierProvider<ReactionController, Map<String, bool>>(
      ReactionController.new,
    );
