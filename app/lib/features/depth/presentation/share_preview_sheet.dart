import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/rendering/offscreen_renderer.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/design/theme/share_render_host.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/today_content.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 공유 미리보기 시트(`share-preview`) 본문. 시트 틀(`sheet` `half`) 안에 놓습니다.
///
/// 위에서부터 비율 선택(`segmented`), 공유 이미지 미리보기, 공유 버튼입니다. 이미지 내용은
/// 오늘 화면과 같은 값([todayContentProvider])을 `shareImageOf`가 바꿔 주고, 비율을 바꾸면
/// 미리보기가 스며 나타납니다(컴포넌트의 `appear.seep`). 이미지는 기기가 다크여도 라이트입니다(V5).
///
/// 공유 버튼은 같은 내용을 [offscreenRendererProvider]로 선택한 비율의 논리 크기에 그려 PNG로
/// 만든 뒤 OS 공유 시트(`ShareSheet.sharePng`)로 넘깁니다(출구 `system-share`, 결정 D47).
/// 글은 태그라인(`share-preview.image.tagline`)입니다. 처리 중에는 버튼 점이 숨 쉬고,
/// 비율 선택과 버튼이 잠겨 연타해도 한 번만 공유합니다. 실패하면 오류 toast만 보이고
/// 시트는 그대로 남습니다.
class SharePreviewSheet extends ConsumerStatefulWidget {
  /// 공유 미리보기 시트 본문을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends ConsumerState<SharePreviewSheet> {
  /// 미리보기가 차지할 수 있는 가장 큰 높이. 9:16이 시트를 가득 채우지 않게 합니다.
  static const double _previewMaxHeight = 360;

  ShareImageVariant _variant = ShareImageVariant.story;
  bool _sharing = false;

  ShareImage _imageFor(ShareImageVariant variant, TodayContent content) =>
      shareImageOf(
        variant: variant,
        date: content.view.date,
        daily: content.view.daily,
        names: content.names,
        l10n: AppLocalizations.of(context),
        locale: Localizations.localeOf(context),
        timezone: ref.watch(profileTimezoneProvider),
      );

  /// 고른 비율로 그려 OS 공유 시트에 넘깁니다. 이미 하는 중이면 아무것도 하지 않습니다.
  Future<void> _share(TodayContent content) async {
    // 같은 프레임의 연타도 막도록 setState 전에 먼저 잠급니다.
    if (_sharing) {
      return;
    }
    _sharing = true;
    setState(() {});
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final variant = _variant;
    final image = _imageFor(variant, content);
    final renderer = ref.read(offscreenRendererProvider);
    final shareSheet = ref.read(shareSheetProvider);
    final reporter = ref.read(crashReporterProvider);
    final text = shareTextOf(l10n);
    String? failure;
    try {
      // 로고를 먼저 읽어 두어 캡처에 빠지지 않게 합니다.
      await ShareImage.precache();
      final png = await renderer.render(
        ShareRenderHost(locale: locale, child: image),
        ShareImage.logicalSize(variant),
      );
      await shareSheet.sharePng(png, text: text);
    } on AppError catch (error) {
      failure = errorMessage(l10n, error);
    } on Object catch (error, stack) {
      // 그리지 못한 이유를 개발자가 알 길이 이것뿐입니다.
      reporter.record(CrashSummary.from(error), stack);
      failure = errorMessage(l10n, UnexpectedError(error));
    }
    if (!mounted) {
      return;
    }
    setState(() => _sharing = false);
    if (failure != null) {
      showMyungliToast(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = ref.watch(todayContentProvider);
    return ScreenStateView<TodayContent>(
      value: content,
      onRetry: () =>
          unawaited(ref.read(dailyControllerProvider.notifier).reload()),
      dataWithNotice: (value, notice) => Padding(
        padding: const EdgeInsets.only(bottom: Space.s24),
        // 스크롤하지 않습니다. 남는 높이에 맞춰 미리보기만 줄어들어 공유 버튼이 늘 보입니다.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            notice,
            Segmented<ShareImageVariant>(
              items: [
                SegmentedItem(
                  ShareImageVariant.story,
                  l10n.sharePreviewRatioLabelStory,
                ),
                SegmentedItem(
                  ShareImageVariant.feed,
                  l10n.sharePreviewRatioLabelFeed,
                ),
                SegmentedItem(
                  ShareImageVariant.square,
                  l10n.sharePreviewRatioLabelSquare,
                ),
              ],
              selected: _variant,
              // 그리는 도중 비율이 바뀌어 다른 그림이 나가지 않게 처리 중에는 잠급니다.
              onChanged: _sharing
                  ? null
                  : (variant) => setState(() => _variant = variant),
              label: l10n.sharePreviewRatioGroup,
              identifier: SlotIds.sharePreviewRatioLabel,
            ),
            const SizedBox(height: Space.s16),
            Flexible(
              child: _Preview(
                image: _imageFor(_variant, value),
                maxHeight: _previewMaxHeight,
              ),
            ),
            const SizedBox(height: Space.s24),
            PrimaryButton(
              label: l10n.sharePreviewCtaShare,
              identifier: SlotIds.sharePreviewCtaShare,
              loading: _sharing,
              onPressed: () => unawaited(_share(value)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가운데 정렬한 미리보기. 높이는 [maxHeight]와 남는 높이 가운데 작은 쪽을 넘지 않도록
/// 폭을 줄입니다(비율은 그대로).
class _Preview extends StatelessWidget {
  const new({required this.image, required this.maxHeight});

  final ShareImage image;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final size = ShareImage.logicalSize(image.variant);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight < maxHeight
            ? constraints.maxHeight
            : maxHeight;
        return Center(
          child: SizedBox(
            width: height * size.width / size.height,
            child: ShareImagePreview(image: image),
          ),
        );
      },
    );
  }
}
