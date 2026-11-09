/// `DiarySummary` JSON 한 편.
typedef DiarySummaryJson = Map<String, Object?>;

/// 대역 서버의 `getDiaryStats` 집계(server 결정 S146).
///
/// * `entryCount`는 살아 있는 일기 편수입니다(편 단위).
/// * `dayKinds`는 `DayKind` 네 값을 모두 담고(0이어도), 살아 있는 일기가 있는 날짜를 날짜당 한 번
///   셉니다. `dayKind`가 없는 날(1.1.0 전 날짜 기록)은 어디에도 세지 않습니다.
/// * `topTags`는 대표 태그(`featuredTags`)가 붙은 날짜 수 내림차순, 같으면 키 오름차순으로
///   최대 [maxTopTags]개입니다. `polarity`는 그 태그가 붙은 가장 최근 날짜의 값입니다.
abstract final class FakeDiaryStats {
  /// 계약 `DiaryStats.topTags`의 상한.
  static const int maxTopTags = 3;

  /// 계약 `DayKind`의 네 값(순서는 정해져 있지 않아 선언 순서로 냅니다).
  static const List<String> dayKinds = [
    'gwiin_day',
    'yongsin_day',
    'gisin_day',
    'ordinary_day',
  ];

  /// [entries](살아 있는 일기의 `DiarySummary` JSON 전부)로 `DiaryStats` JSON을 만듭니다.
  static Map<String, Object> compute(List<DiarySummaryJson> entries) {
    // 날짜 → 그날의 dayKind (같은 날 기록은 같은 값이라 아무 편의 값을 씁니다).
    final dayKindByDate = <String, String>{};
    // 날짜 → 그날 대표 태그 키 → 길흉.
    final tagsByDate = <String, Map<String, String>>{};
    for (final entry in entries) {
      final date = entry['date']! as String;
      final dayKind = entry['dayKind'];
      if (dayKind is String) {
        dayKindByDate[date] = dayKind;
      }
      final dayTags = tagsByDate.putIfAbsent(date, () => {});
      for (final tag in entry['featuredTags'] as List<Object?>? ?? const []) {
        final json = tag! as Map<String, Object?>;
        dayTags[json['key']! as String] = json['polarity']! as String;
      }
    }

    final kindDays = {for (final kind in dayKinds) kind: 0};
    for (final kind in dayKindByDate.values) {
      kindDays[kind] = (kindDays[kind] ?? 0) + 1;
    }

    // 최근 날짜가 나중에 오도록 날짜 오름차순으로 훑어 마지막 polarity를 남깁니다.
    final tagDays = <String, int>{};
    final tagPolarity = <String, String>{};
    for (final date in tagsByDate.keys.toList()..sort()) {
      tagsByDate[date]!.forEach((key, polarity) {
        tagDays[key] = (tagDays[key] ?? 0) + 1;
        tagPolarity[key] = polarity;
      });
    }
    final tagKeys = tagDays.keys.toList()
      ..sort((a, b) {
        final byDays = tagDays[b]!.compareTo(tagDays[a]!);
        return byDays != 0 ? byDays : a.compareTo(b);
      });

    return {
      'entryCount': entries.length,
      'dayKinds': [
        for (final kind in dayKinds) {'dayKind': kind, 'days': kindDays[kind]!},
      ],
      'topTags': [
        for (final key in tagKeys.take(maxTopTags))
          {
            'tag': {'key': key, 'polarity': tagPolarity[key]!},
            'days': tagDays[key]!,
          },
      ],
    };
  }
}
