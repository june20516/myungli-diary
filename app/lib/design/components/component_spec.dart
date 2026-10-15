import 'package:flutter/foundation.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/ad_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';

/// 컴포넌트 하나가 따르는 명세 요약. 대조 테스트가 명세 JSON과 비교합니다.
///
/// 컴포넌트마다 `static const spec`을 두고 [implementedComponents]에 올립니다.
@immutable
final class ComponentSpec {
  /// 명세 id와 변형·상태 집합으로 만듭니다.
  const new(this.id, this.variants, this.states);

  /// IA 컴포넌트 id(예: `tab-bar`).
  final String id;

  /// 명세 `variants[].id` 집합.
  final Set<String> variants;

  /// 명세 `states` 키 집합. `pressed` 같은 상호작용 상태도 그대로 담습니다.
  final Set<String> states;
}

/// 구현을 마친 컴포넌트의 명세 목록. Task 17~19가 채웁니다.
const List<ComponentSpec> implementedComponents = [
  MyungliTabBar.spec,
  MyungliAppBar.spec,
  MyungliSheetFrame.spec,
  AdBanner.spec,
  MyungliDialog.spec,
  MyungliToast.spec,
  NoticeBanner.spec,
  SkeletonBlock.spec,
  EmptyState.spec,
  ErrorState.spec,
  SentenceBlock.spec,
  TermToken.spec,
  DepthLink.spec,
  ReactionButton.spec,
  PrimaryButton.spec,
  InputStep.spec,
  MyungliTextField.spec,
  Segmented.spec,
  CheckRow.spec,
  BirthDatePicker.spec,
  TimePicker.spec,
  CitySearch.spec,
  DayCharacter.spec,
  LuckyCardRow.spec,
  GuideQuestionCard.spec,
  ShareImage.spec,
  ShareButton.spec,
  SocialLoginButton.spec,
];
