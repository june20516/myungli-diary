import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _magnifyingGlass = AppGlyph(
  light: PhosphorIconsLight.magnifyingGlass,
  regular: PhosphorIconsRegular.magnifyingGlass,
);

/// 도시 검색과 결과 목록(`city-search`).
///
/// 위에 `text-field`(앞 아이콘 `magnifying-glass`), 아래에 결과 카드가 놓입니다.
/// [results]가 null이면 결과 자리가 없고, 불러오는 중이면 skeleton 줄 3개, 빈 목록이면
/// [EmptyState], 오류면 [ErrorState]입니다. 줄은 도시 이름(검색어와 맞는 부분은 굵게 600)과
/// 지역 자리([City.country] 코드, 결정 A20 ⑤)이고 눌림은 `press.ink`입니다.
///
/// 글자를 칠 때마다 결과가 바뀌어도 목록을 움직이지 않습니다. 이 위젯은 스크롤을 갖지
/// 않고 화면의 스크롤 안에 놓이며, 다시 불러오는 동안(이전 값이 남은 loading)에는 이전 줄을
/// 그대로 둬서 높이가 줄었다 늘지 않게 합니다. 결과 수는 "결과 N개"로 알립니다.
class CitySearch extends StatefulWidget {
  /// 도시 검색을 만듭니다.
  ///
  /// [label]은 입력칸 이름(스크린리더), [hint]는 비었을 때 예시, [emptyBody]는 빈 목록 문장,
  /// [onRetry]는 오류 화면의 다시 시도입니다. [skeletonDelay]·[animated]는 golden과
  /// 테스트에서 skeleton을 바로·정지 상태로 그릴 때 줄입니다.
  const new({
    required this.label,
    required this.onQueryChanged,
    required this.results,
    required this.onSelected,
    required this.emptyBody,
    required this.onRetry,
    this.hint,
    this.skeletonDelay = SkeletonBlock.defaultDelay,
    this.animated = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('city-search', {}, {
    'pressed',
    'loading',
    'empty',
  });

  /// 결과 카드를 찾는 테스트용 키.
  static const Key resultsKey = ValueKey('city-search-results');

  /// 도시 [cityId]의 결과 줄을 찾는 테스트용 키.
  static Key rowKey(String cityId) => ValueKey('city-search-row-$cityId');

  static const double _rowMinHeight = 56;
  static const int _skeletonRows = 3;

  /// 입력칸 이름(스크린리더 라벨).
  final String label;

  /// 비었을 때 보이는 예시.
  final String? hint;

  /// 글자가 바뀔 때 검색어 전체.
  final ValueChanged<String> onQueryChanged;

  /// 검색 결과. null이면 결과 자리가 없습니다.
  final AsyncValue<List<City>>? results;

  /// 줄을 눌렀을 때 그 도시.
  final ValueChanged<City> onSelected;

  /// 결과가 빈 목록일 때 문장.
  final String emptyBody;

  /// 오류 화면의 다시 시도.
  final VoidCallback onRetry;

  /// skeleton을 보이기 전 대기(기본 300ms).
  final Duration skeletonDelay;

  /// false면 skeleton이 숨 쉬지 않고 정지 상태로 그립니다(golden).
  final bool animated;

  @override
  State<CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends State<CitySearch> {
  String _query = '';

  void _onChanged(String value) {
    setState(() => _query = value);
    widget.onQueryChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MyungliTextField(
          label: widget.label,
          hint: widget.hint,
          leadingIcon: _magnifyingGlass,
          onChanged: _onChanged,
        ),
        if (widget.results case final results?)
          Padding(
            padding: const EdgeInsets.only(top: Space.s12),
            child: _buildResults(context, results),
          ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, AsyncValue<List<City>> results) {
    if (results.hasError && !results.isLoading) {
      final error = results.error;
      return ErrorState(
        error: error is AppError ? error : UnexpectedError(error ?? 'unknown'),
        onRetry: widget.onRetry,
      );
    }
    // 다시 불러오는 중에는 이전 줄을 그대로 둡니다.
    final cities = results.value;
    if (cities == null) {
      return SkeletonBlock(
        delay: widget.skeletonDelay,
        animated: widget.animated,
        child: Column(
          spacing: Space.s8,
          children: [
            for (var i = 0; i < CitySearch._skeletonRows; i++)
              SkeletonBone(
                height: CitySearch._rowMinHeight,
                borderRadius: Radii.md,
                index: i,
                animated: widget.animated,
              ),
          ],
        ),
      );
    }
    if (cities.isEmpty) return EmptyState(body: widget.emptyBody);
    return LiveAnnouncement(
      label: AppLocalizations.of(context).citySearchResults(cities.length),
      role: SemanticsRole.status,
      child: _ResultsCard(
        key: CitySearch.resultsKey,
        cities: cities,
        query: _query.trim(),
        onSelected: widget.onSelected,
      ),
    );
  }
}

/// 묶음 카드 모양의 결과 목록(`settings-row`와 같은 모양).
class _ResultsCard extends StatelessWidget {
  const new({
    required this.cities,
    required this.query,
    required this.onSelected,
    super.key,
  });

  final List<City> cities;
  final String query;
  final ValueChanged<City> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    const radius = BorderRadius.all(Radius.circular(Radii.md));
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bgSheet, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            for (var i = 0; i < cities.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: Space.s16),
                  child: SizedBox(
                    height: 1,
                    width: double.infinity,
                    child: ColoredBox(color: colors.line),
                  ),
                ),
              _CityRow(
                key: ValueKey(cities[i].id),
                city: cities[i],
                query: query,
                onSelected: onSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const new({
    required this.city,
    required this.query,
    required this.onSelected,
    super.key,
  });

  final City city;
  final String query;
  final ValueChanged<City> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nameStyle = tokens.typography.bodyUi.copyWith(
      color: tokens.colors.textPrimary,
    );
    return PressInkTarget(
      semanticLabel: '${city.name}, ${city.country}',
      onTap: () => onSelected(city),
      borderRadius: BorderRadius.zero,
      child: ConstrainedBox(
        key: CitySearch.rowKey(city.id),
        constraints: const BoxConstraints(minHeight: CitySearch._rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s16,
            vertical: Space.s8,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(_nameSpan(city.name, query, nameStyle)),
                Text(
                  city.country,
                  style: tokens.typography.captionMd.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [name]에서 [query]와 맞는 첫 부분(대소문자 무시)만 굵게(600) 만듭니다.
  static TextSpan _nameSpan(String name, String query, TextStyle style) {
    final lower = name.toLowerCase();
    final needle = query.toLowerCase();
    // 소문자로 바꿀 때 길이가 달라지는 글자가 있으면 위치가 어긋나므로 굵게 하지 않습니다.
    final start = query.isEmpty || lower.length != name.length
        ? -1
        : lower.indexOf(needle);
    if (start < 0) return TextSpan(text: name, style: style);
    final end = start + needle.length;
    return TextSpan(
      style: style,
      children: [
        if (start > 0) TextSpan(text: name.substring(0, start)),
        TextSpan(
          text: name.substring(start, end),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (end < name.length) TextSpan(text: name.substring(end)),
      ],
    );
  }
}
