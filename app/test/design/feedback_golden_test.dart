import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../support/golden.dart';

Widget _dialogs() => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 12,
  children: [
    DialogCard(
      variant: DialogVariant.confirm,
      title: '이대로 나갈까요?',
      body: '쓰던 내용은 초안으로 남아요.',
      confirm: '나가기',
      cancel: '계속 쓰기',
    ),
    DialogCard(
      variant: DialogVariant.destructive,
      title: '일기를 지울까요?',
      body: '지우면 되돌릴 수 없어요. 태그와 반응도 함께 사라져요.',
      confirm: '지우기',
      cancel: '취소',
    ),
    DialogCard(
      variant: DialogVariant.notice,
      body: '이미 사주를 저장한 계정이면 방금 입력한 정보 대신 저장된 정보를 써요.',
      confirm: '확인',
    ),
  ],
);

Widget _toasts() => const Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: 12,
  children: [
    ToastPill(message: '저장했어요'),
    ToastPill(
      message: '저장했어요. 오늘의 일기에 태그가 두 개 붙었고 내일 아침에 다시 볼 수 있어요.',
      icon: AppGlyph(
        light: PhosphorIconsLight.checkCircle,
        regular: PhosphorIconsRegular.checkCircle,
      ),
    ),
  ],
);

Widget _banners() => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    NoticeBanner(
      variant: NoticeBannerVariant.offline,
      message: '인터넷에 연결되어 있지 않아 받아둔 내용을 보여 드려요.',
    ),
    NoticeBanner(
      variant: NoticeBannerVariant.timeUnknown,
      message: '태어난 시간을 몰라 시주 없이 풀이했어요.',
    ),
    NoticeBanner(variant: NoticeBannerVariant.draft, message: '이어 쓸 일기가 있어요.'),
  ],
);

Widget _skeletons() => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 16,
  children: [
    SkeletonBlock(delay: Duration.zero, animated: false),
    SkeletonBlock(
      delay: Duration.zero,
      animated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          SkeletonBone(height: 120, borderRadius: Radii.lg, animated: false),
          SkeletonBone(
            height: 16,
            width: 200,
            borderRadius: Radii.xs,
            index: 1,
            animated: false,
          ),
        ],
      ),
    ),
  ],
);

Widget _empty() => SizedBox(
  height: 440,
  child: EmptyState(
    body: '아직 쓴 일기가 없어요. 오늘의 한 줄부터 남겨 볼까요?',
    action: PrimaryButton(label: '일기 쓰기', onPressed: () {}),
  ),
);

Widget _errors() => Column(
  spacing: 12,
  children: [
    SizedBox(
      height: 440,
      child: ErrorState(error: const TimeoutError(), onRetry: () {}),
    ),
    SizedBox(
      height: 440,
      child: ErrorState(error: const OfflineError(), onRetry: () {}),
    ),
    SizedBox(
      height: 440,
      child: ErrorState(
        error: const ProblemError(
          code: 'x',
          status: 500,
          fieldErrors: [],
          traceId: 'trace-abc-123',
        ),
        onRetry: () {},
      ),
    ),
  ],
);

void main() {
  goldenTest('dialog: confirm·destructive', (tester) async {
    await goldenMatrix(tester, 'feedback_dialog', _dialogs);
  });

  goldenTest('toast: 한 줄·두 줄과 아이콘', (tester) async {
    await goldenMatrix(tester, 'feedback_toast', _toasts);
  });

  goldenTest('notice-banner: offline·time-unknown·draft', (tester) async {
    await goldenMatrix(
      tester,
      'feedback_notice_banner',
      _banners,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('skeleton: 글줄·직접 짠 배치', (tester) async {
    await goldenMatrix(tester, 'feedback_skeleton', _skeletons);
  });

  goldenTest('empty-state', (tester) async {
    await goldenMatrix(tester, 'feedback_empty_state', _empty);
  });

  goldenTest('error-state: generic·offline·문의 번호', (tester) async {
    await goldenMatrix(tester, 'feedback_error_state', _errors);
  });
}
