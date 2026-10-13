import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar_inset_scope.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';

/// 탭 id 순서의 루트 화면. IA `tabs[].root`와 같습니다.
const List<String> tabRoots = [
  ScreenIds.today,
  ScreenIds.calendar,
  ScreenIds.diaryList,
  ScreenIds.mySaju,
];

/// 이 기기에서 광고 동의를 거쳤는지. 진입 계산이 끝날 때마다 다시 읽습니다.
final adConsentGivenProvider = FutureProvider<bool>((ref) {
  ref.watch(entryStateProvider);
  return ref.watch(deviceFlagsStoreProvider).readBool(adConsentDoneKey);
});

/// 탭 4개 셸: 화면 내용 위에 하단 틀([MyungliBottomBar])을 얹습니다.
///
/// 하단 틀 높이를 [BottomBarInsetScope]로 하위(toast 등)에 주고, 화면 내용에는
/// 아래 여백(`MediaQuery.padding`)으로 같은 높이를 줘 스크롤 목록이 틀에 가리지 않게 합니다.
class TabShell extends ConsumerStatefulWidget {
  /// [shell]을 하단 틀과 함께 보입니다. [path]는 현재 위치입니다.
  const new(this.shell, {required this.path, super.key});

  /// 탭별 Navigator를 가진 셸.
  final StatefulNavigationShell shell;

  /// 현재 경로(`/today` 등).
  final String path;

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  double _barHeight = 0;

  bool get _isTabRoot =>
      tabRoots.contains(widget.path.replaceFirst(RegExp('^/'), ''));

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final adFree =
        ref.watch(meProvider.select((me) => me?.adFree.active)) ?? false;
    final consentGiven = ref.watch(adConsentGivenProvider).value ?? false;
    final media = MediaQuery.of(context);
    final bottom = math.max(_barHeight, media.padding.bottom);
    return BottomBarInsetScope(
      height: _barHeight,
      // 하단 틀의 글자가 Material 조상 없이 그려져 밑줄이 생기지 않게 합니다.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(bottom: bottom),
                  viewPadding: media.viewPadding.copyWith(bottom: bottom),
                ),
                child: SheetScreenBelow(child: shell),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MyungliBottomBar(
                index: shell.currentIndex,
                onSelect: shell.goBranch,
                onScrollToTop: () =>
                    shell.goBranch(shell.currentIndex, initialLocation: true),
                showAd: _isTabRoot,
                adFree: adFree,
                consentGiven: consentGiven,
                onHeightChanged: (height) {
                  if (mounted && height != _barHeight) {
                    setState(() => _barHeight = height);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
