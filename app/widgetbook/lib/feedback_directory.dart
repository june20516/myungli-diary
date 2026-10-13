import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

Widget _dialogOpener(DialogVariant variant) => Builder(
  builder: (context) => FilledButton(
    onPressed: () => showMyungliDialog(
      context,
      variant: variant,
      title: variant == DialogVariant.destructive ? '일기를 지울까요?' : '이대로 나갈까요?',
      body: variant == DialogVariant.destructive
          ? '지우면 되돌릴 수 없어요.'
          : '쓰던 내용은 초안으로 남아요.',
      confirm: variant == DialogVariant.destructive ? '지우기' : '나가기',
      cancel: variant == DialogVariant.destructive ? '취소' : '계속 쓰기',
    ),
    child: Text('${variant.name} 열기'),
  ),
);

Widget _fixedHeight(Widget child) =>
    SizedBox(height: 360, width: 360, child: child);

/// 피드백 카탈로그: dialog, toast, notice-banner, skeleton, empty-state, error-state.
final WidgetbookFolder feedbackDirectory = WidgetbookFolder(
  name: '피드백',
  children: [
    WidgetbookComponent(
      name: 'dialog',
      useCases: [
        WidgetbookUseCase(
          name: 'confirm',
          builder: (context) =>
              Stage(child: _dialogOpener(DialogVariant.confirm)),
        ),
        WidgetbookUseCase(
          name: 'destructive · 처음 초점은 취소',
          builder: (context) =>
              Stage(child: _dialogOpener(DialogVariant.destructive)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'toast',
      useCases: [
        WidgetbookUseCase(
          name: '눌러서 보기 · 연속으로 누르면 하나만',
          builder: (context) => Stage(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showMyungliToast(context, '저장했어요'),
                child: const Text('토스트 보이기'),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '알약 모양',
          builder: (context) => const Stage(
            child: ToastPill(message: '저장했어요. 두 줄까지 보이고 그 뒤는 말줄임표예요.'),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'notice-banner',
      useCases: [
        for (final variant in NoticeBannerVariant.values)
          WidgetbookUseCase(
            name: variant.name,
            builder: (context) => Stage(
              child: SizedBox(
                width: 360,
                child: NoticeBanner(
                  variant: variant,
                  message: switch (variant) {
                    NoticeBannerVariant.offline =>
                      '인터넷에 연결되어 있지 않아 받아둔 내용을 보여 드려요.',
                    NoticeBannerVariant.timeUnknown =>
                      '태어난 시간을 몰라 시주 없이 풀이했어요.',
                    NoticeBannerVariant.draft => '이어 쓸 일기가 있어요.',
                  },
                ),
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'skeleton',
      useCases: [
        WidgetbookUseCase(
          name: '글줄',
          builder: (context) => const Stage(
            child: SizedBox(
              width: 360,
              child: SkeletonBlock(delay: Duration.zero),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '직접 짠 배치',
          builder: (context) => const Stage(
            child: SizedBox(
              width: 360,
              child: SkeletonBlock(
                delay: Duration.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    SkeletonBone(height: 120, borderRadius: 20),
                    SkeletonBone(
                      height: 16,
                      width: 200,
                      borderRadius: 4,
                      index: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'empty-state',
      useCases: [
        WidgetbookUseCase(
          name: '문장 + 주 버튼',
          builder: (context) => Stage(
            child: _fixedHeight(
              EmptyState(
                body: '아직 쓴 일기가 없어요. 오늘의 한 줄부터 남겨 볼까요?',
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('일기 쓰기'),
                ),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '문장만',
          builder: (context) => Stage(
            child: _fixedHeight(const EmptyState(body: '이 태그의 일기가 아직 없어요.')),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'error-state',
      useCases: [
        WidgetbookUseCase(
          name: 'generic',
          builder: (context) => Stage(
            child: _fixedHeight(
              ErrorState(error: const TimeoutError(), onRetry: () {}),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'offline',
          builder: (context) => Stage(
            child: _fixedHeight(
              ErrorState(error: const OfflineError(), onRetry: () {}),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '문의 번호 (길게 눌러 복사)',
          builder: (context) => Stage(
            child: _fixedHeight(
              ErrorState(
                error: const ProblemError(
                  code: 'x',
                  status: 500,
                  fieldErrors: [],
                  traceId: 'trace-abc-123',
                ),
                onRetry: () {},
              ),
            ),
          ),
        ),
      ],
    ),
  ],
);
