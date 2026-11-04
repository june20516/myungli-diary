// 하루 사용 흐름을 app의 실제 호출 순서로 재현합니다(L1 plan §3). 근거는 app 코드 읽기 결과(2026-11-04)입니다.
// * 앱 열기: getAppConfig → refreshToken(access token은 메모리에만 있어 열 때마다 갱신) → getMe
//   (app/lib/app/entry/entry_providers.dart:142-199, core/api/interceptors/auth.dart:54-66)
// * today 화면: getDaily, getGlossary(If-None-Match), listDiaries(오늘), listSchedules(오늘)을 동시에
//   (features/today/application/today_content.dart:73-80)
// * 일기 쓰기: getDaily(그날) → createDiary(Idempotency-Key) → getDiary(id) → today로 돌아와 listDiaries(오늘)
//   (features/diary/application/diary_edit.dart:178-236, :360-377, diary_view_screen.dart:81)
// * 캘린더: getCalendar 석 달, listSchedules와 listDiaries(42칸), getGlossary를 동시에
//   (features/calendar/presentation/calendar_screen.dart:182-197, calendar_providers.dart:162-183)
// app은 429, 503, 시간 초과에 자동 재시도하지 않으므로(core/api/http_client.dart:62-92) 여기서도 다시 보내지 않습니다.

import { check } from 'k6';
import { intEnv } from './config.js';
import * as api from './api.js';
import { calendarGrid, neighborMonths, seoulDate } from './dates.js';

// 흐름 비율(%)입니다. 세션마다 today 화면은 늘 보고, 아래는 각각 따로 정합니다.
const REACTION_PERCENT = intEnv('REACTION_PERCENT', 10);
const DIARY_PERCENT = intEnv('DIARY_PERCENT', 25);
const CALENDAR_PERCENT = intEnv('CALENDAR_PERCENT', 20);

// DAILY_OFFSET_DAYS는 today 화면이 여는 날짜를 오늘에서 며칠 옮길지입니다. cold 회차는 아직 계산하지 않은 날짜로
// 옮겨 첫 getDaily가 엔진을 부르게 합니다(warm은 0, precompute 뒤). 일기와 캘린더는 늘 실제 오늘 기준입니다.
const DAILY_OFFSET_DAYS = intEnv('DAILY_OFFSET_DAYS', 0);

// DIARY_SPREAD_DAYS는 일기 날짜를 오늘부터 며칠 전까지 나눌지입니다. 하루 10편 상한(D83)에 닿지 않게 합니다.
const DIARY_SPREAD_DAYS = intEnv('DIARY_SPREAD_DAYS', 7);

const ok = (res) => res.status >= 200 && res.status < 300;
const okOrNotModified = (res) => ok(res) || res.status === 304;

function percent(value) {
  return Math.random() * 100 < value;
}

function json(res) {
  try {
    return res.json();
  } catch (_) {
    return null;
  }
}

// openApp은 앱을 열어 토큰을 갱신하고 계정을 확인합니다. 갱신에 실패하면 테스트 로그인으로 다시 받습니다
// (회차 시작 전 토큰이 다른 실행에서 쓰였을 때). 성공하면 access token을 돌려줍니다.
function openApp(account) {
  api.send(api.getAppConfig());
  let res = api.send(api.refreshToken(account.refresh));
  if (!ok(res)) {
    res = api.send(api.testLogin(account.label));
    check(res, { 'testLogin 다시 로그인': ok });
    if (!ok(res)) {
      return null;
    }
    account.refresh = json(res).tokens.refreshToken;
    return json(res).tokens.accessToken;
  }
  const pair = json(res);
  account.refresh = pair.refreshToken;
  check(api.send(api.getMe(pair.accessToken)), { getMe: ok });
  return pair.accessToken;
}

function todayScreen(account, token, date) {
  const today = seoulDate(0);
  const [daily, glossary] = api.sendAll([
    api.getDaily(token, date),
    api.getGlossary(token, account.glossaryEtag),
    api.listDiaries(token, today, today),
    api.listSchedules(token, today, today),
  ]);
  check(daily, { getDaily: ok });
  check(glossary, { getGlossary: okOrNotModified });
  if (glossary.status === 200 && glossary.headers.Etag) {
    account.glossaryEtag = glossary.headers.Etag;
  }
  return json(daily);
}

function react(token, date, daily) {
  const head = daily && daily.fortune && daily.fortune.head;
  if (head && head.reactable) {
    check(api.send(api.putReaction(token, date, head.slot)), { putReaction: ok });
  }
}

function writeDiary(token, label) {
  const today = seoulDate(0);
  const date = seoulDate(-Math.floor(Math.random() * DIARY_SPREAD_DAYS));
  api.send(api.getDaily(token, date));
  const key = `${label}-${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
  const created = api.send(api.createDiary(token, date, `부하 테스트 일기 ${key}`, key));
  check(created, { createDiary: ok });
  const diary = ok(created) ? json(created) : null;
  if (diary && diary.id) {
    check(api.send(api.getDiary(token, diary.id)), { getDiary: ok });
  }
  api.send(api.listDiaries(token, today, today));
}

function openCalendar(account, token) {
  const today = seoulDate(0);
  const grid = calendarGrid(today);
  const reqs = neighborMonths(today).map((m) => api.getCalendar(token, m.year, m.month));
  reqs.push(api.listSchedules(token, grid.from, grid.to));
  reqs.push(api.listDiaries(token, grid.from, grid.to));
  reqs.push(api.getGlossary(token, account.glossaryEtag));
  const responses = api.sendAll(reqs);
  check(responses[1], { getCalendar: ok });
}

// session은 사용자 한 명이 앱을 한 번 여는 흐름입니다. account는 VU가 들고 있는 계정 상태(label, refresh, glossaryEtag)입니다.
export function session(account) {
  const token = openApp(account);
  if (!token) {
    return;
  }
  const date = seoulDate(DAILY_OFFSET_DAYS);
  const daily = todayScreen(account, token, date);
  if (percent(REACTION_PERCENT)) {
    react(token, date, daily);
  }
  if (percent(DIARY_PERCENT)) {
    writeDiary(token, account.label);
  }
  if (percent(CALENDAR_PERCENT)) {
    openCalendar(account, token);
  }
}
