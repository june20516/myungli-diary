import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/app_config.dart';
import 'package:myungli_diary/core/api/gen/model/apple_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour_request.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/chart_pillars.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/city_list.dart';
import 'package:myungli_diary/core/api/gen/model/color_card.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/api/gen/model/consent_request.dart';
import 'package:myungli_diary/core/api/gen/model/daeun.dart';
import 'package:myungli_diary/core/api/gen/model/daeun_period.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/daily_cards.dart';
import 'package:myungli_diary/core/api/gen/model/day_tags.dart';
import 'package:myungli_diary/core/api/gen/model/deletion_scheduled.dart';
import 'package:myungli_diary/core/api/gen/model/device.dart';
import 'package:myungli_diary/core/api/gen/model/device_input.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/api/gen/model/diary_input.dart';
import 'package:myungli_diary/core/api/gen/model/diary_list.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/api/gen/model/direction_card.dart';
import 'package:myungli_diary/core/api/gen/model/element_weight.dart';
import 'package:myungli_diary/core/api/gen/model/entitlements.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/field_error.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/focus_time_card.dart';
import 'package:myungli_diary/core/api/gen/model/fortune.dart';
import 'package:myungli_diary/core/api/gen/model/glossary.dart';
import 'package:myungli_diary/core/api/gen/model/health.dart';
import 'package:myungli_diary/core/api/gen/model/hidden_stem.dart';
import 'package:myungli_diary/core/api/gen/model/hidden_stems_at.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/kakao_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_response.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_date.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/minimum_version.dart';
import 'package:myungli_diary/core/api/gen/model/notice.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/number_card.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/preview.dart';
import 'package:myungli_diary/core/api/gen/model/preview_request.dart';
import 'package:myungli_diary/core/api/gen/model/problem.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/profile_input.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/api/gen/model/profile_response.dart';
import 'package:myungli_diary/core/api/gen/model/reaction_input.dart';
import 'package:myungli_diary/core/api/gen/model/refresh_request.dart';
import 'package:myungli_diary/core/api/gen/model/relation.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_input.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_list.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_patch.dart';
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/api/gen/model/seun_year.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_at.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/api/gen/model/solar_term.dart';
import 'package:myungli_diary/core/api/gen/model/strength.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_at.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage_at.dart';
import 'package:myungli_diary/core/api/gen/model/yongsin.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(
  dynamic value,
  String targetType, {
  bool growable = true,
}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'AdFree':
      return AdFree.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AppConfig':
      return AppConfig.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AppleLoginRequest':
      return AppleLoginRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Birth':
      return Birth.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'BirthHour':
      return BirthHour.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'BirthHourRequest':
      return BirthHourRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BirthPlace':
      return BirthPlace.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'BirthTime':
      return BirthTime.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Branch':
    case 'Calendar':
      return Calendar.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CalendarDay':
      return CalendarDay.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CalendarType':
    case 'Chart':
      return Chart.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ChartPillars':
      return ChartPillars.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'City':
      return City.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CityList':
      return CityList.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ColorCard':
      return ColorCard.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ConsentDocument':
      return ConsentDocument.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ConsentRequest':
      return ConsentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Daeun':
      return Daeun.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DaeunPeriod':
      return DaeunPeriod.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Daily':
      return Daily.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DailyCards':
      return DailyCards.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DayKind':
    case 'DayTags':
      return DayTags.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DeletionScheduled':
      return DeletionScheduled.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Device':
      return Device.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DeviceInput':
      return DeviceInput.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DevicePlatform':
    case 'Diary':
      return Diary.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DiaryInput':
      return DiaryInput.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DiaryList':
      return DiaryList.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DiarySummary':
      return DiarySummary.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Direction':
    case 'DirectionCard':
      return DirectionCard.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ElementRole':
    case 'ElementWeight':
      return ElementWeight.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Entitlements':
      return Entitlements.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Evidence':
      return Evidence.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'EvidenceAccess':
    case 'FieldError':
      return FieldError.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'FiveElement':
    case 'FocusSlot':
      return FocusSlot.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'FocusTimeCard':
      return FocusTimeCard.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Fortune':
      return Fortune.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Glossary':
      return Glossary.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Health':
      return Health.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HiddenStem':
      return HiddenStem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'HiddenStemsAt':
      return HiddenStemsAt.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Insight':
      return Insight.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'KakaoLoginRequest':
      return KakaoLoginRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Language':
    case 'LoginResponse':
      return LoginResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LuckLevel':
    case 'LunarDate':
      return LunarDate.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'LunarOrSolarDate':
      return LunarOrSolarDate.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Me':
      return Me.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'MinimumVersion':
      return MinimumVersion.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Notice':
      return Notice.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'NoticeCode':
    case 'NotificationSetting':
      return NotificationSetting.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'NumberCard':
      return NumberCard.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Pillar':
      return Pillar.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Position':
    case 'Preview':
      return Preview.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'PreviewRequest':
      return PreviewRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Problem':
      return Problem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Profile':
      return Profile.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ProfileInput':
      return ProfileInput.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ProfilePatch':
      return ProfilePatch.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ProfileResponse':
      return ProfileResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ReactionInput':
      return ReactionInput.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RefreshRequest':
      return RefreshRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Relation':
      return Relation.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RelationKind':
    case 'RenderedText':
      return RenderedText.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Schedule':
      return Schedule.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ScheduleInput':
      return ScheduleInput.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ScheduleList':
      return ScheduleList.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SchedulePatch':
      return SchedulePatch.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ScoreItem':
      return ScoreItem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Segment':
      return Segment.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SeunYear':
      return SeunYear.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ShinsalAt':
      return ShinsalAt.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ShinsalKind':
    case 'SlotText':
      return SlotText.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SolarTerm':
      return SolarTerm.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SolarTermKind':
    case 'Stem':
    case 'Strength':
      return Strength.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'StrengthLevel':
    case 'Tag':
      return Tag.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TenGod':
    case 'TenGodAt':
      return TenGodAt.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TokenPair':
      return TokenPair.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TwelveStage':
    case 'TwelveStageAt':
      return TwelveStageAt.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Yongsin':
      return Yongsin.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'YongsinMethod':
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toList(growable: growable)
            as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toSet()
            as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
          value.keys as Iterable<String>,
          value.values.map(
            (dynamic v) => deserialize<BaseType, BaseType>(
              v,
              targetType,
              growable: growable,
            ),
          ),
        ) as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
