import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';

/// 계정 id는 그대로인 채 계정 데이터가 바뀌었을 때(계정 합치기) invalidate할 뿌리 provider.
///
/// 계정 데이터를 읽는 provider는 모두 이 가운데 하나를 build에서 watch하므로, 뿌리를
/// invalidate하면 연쇄로 다시 만들어지고 다시 받습니다.
///
/// * [cacheStoreProvider]: 오늘·달력·나의 사주·용어·프로필 사본(캐시를 거치는 것 모두).
/// * [diaryRepositoryProvider]: 일기 목록·그날 일기·일기 도장·일기 한 편.
/// * [scheduleRepositoryProvider]: 일정.
/// * [diaryDraftStoreProvider]: 일기 초안(합친 뒤 지웠으므로 쓰는 중인 화면도 다시 읽게).
///
/// 로그아웃·로그인은 계정 id(`currentAccountIdProvider`·`meProvider`)가 바뀌어 저절로 다시
/// 만들어지므로 이 목록을 쓰지 않습니다. 계정 데이터를 읽는 새 뿌리 provider를 만들면 여기에
/// 더합니다.
final List<ProviderOrFamily> accountDataProviders = [
  cacheStoreProvider,
  diaryRepositoryProvider,
  scheduleRepositoryProvider,
  diaryDraftStoreProvider,
];
