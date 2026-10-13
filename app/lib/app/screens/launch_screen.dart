import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';

/// IA `launch` 화면의 상태 id. 처리하는 상태를 레지스트리와 한곳에서 맞춥니다.
const launchHandledStates = {'loading', 'offline'};

/// 앱 시작 화면. 진입 갈래를 계산하는 동안 skeleton, 실패하면 오류와 다시 시도입니다.
///
/// 계산이 끝나면 라우터가 갈래별 화면으로 보내므로 값이 있는 모습은 그리지 않습니다.
/// 값이 남은 채 `hasError`인 경우(다시 시도 실패)도 값을 버리고 오류로 보입니다.
class LaunchScreen extends ConsumerWidget {
  /// launch 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(entryStateProvider);
    // 다시 시도 중에는 이전 오류가 남아 있어도 skeleton이 나와야 합니다.
    final value = entry.hasError && !entry.isLoading
        ? AsyncValue<void>.error(
            entry.error!,
            entry.stackTrace ?? StackTrace.empty,
          )
        : const AsyncValue<void>.loading();
    return Semantics(
      identifier: ScreenIds.launch,
      child: Scaffold(
        key: const ValueKey(ScreenIds.launch),
        body: SafeArea(
          child: ScreenStateView<void>(
            value: value,
            onRetry: () => ref.read(entryStateProvider.notifier).refresh(),
            data: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
