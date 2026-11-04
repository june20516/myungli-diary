// 한계점 측정입니다(L1 plan §4, L1-2 Step 5). 단계마다 도착률을 고정한 scenario 하나를 두고 차례로 돌립니다.
// 도착률 단위는 "세션/초"(사용자 한 명이 앱을 한 번 여는 흐름, lib/flows.js)이고, 세션 하나는 요청 6~15개입니다.
// 단계 경계는 tag scenario(stage_<세션/초>)로 남아 집계 도구가 그대로 나눕니다.
//
// 멈춤 조건(단계마다): 오류(4xx, 5xx, 시간 초과) 1% 넘음, getDaily p95 2초 넘음. 닿으면 k6가 그 단계에서 실행을 멈춥니다.
// 짧은 확인(smoke)은 STAGES=1 STAGE_DURATION=1m입니다.
//
// 실행: README "측정"

import exec from 'k6/execution';
import { ACCOUNTS, accountLabel, intEnv, requireSecret } from '../lib/config.js';
import * as api from '../lib/api.js';
import { session } from '../lib/flows.js';

const STAGES = (__ENV.STAGES || '2,5,10,20,40,80,160,320').split(',').map((v) => {
  const rate = Number.parseInt(v.trim(), 10);
  if (!Number.isInteger(rate) || rate <= 0) {
    throw new Error(`STAGES 값이 양의 정수가 아닙니다: ${v}`);
  }
  return rate;
});
const STAGE_DURATION = __ENV.STAGE_DURATION || '3m';
// STAGE_GAP은 단계 사이 쉬는 시간입니다. 앞 단계의 늦은 응답이 다음 단계 지표에 섞이지 않게 합니다.
const STAGE_GAP = __ENV.STAGE_GAP || '30s';
// 세션 하나에 걸리는 시간(초)의 넉넉한 짐작입니다. VU 수 = 도착률 × 이 값. 모자라면 dropped_iterations로 드러납니다.
const SESSION_SECONDS = intEnv('SESSION_SECONDS', 5);
// RESULT_DIR은 handleSummary가 k6-summary.json을 쓰는 곳입니다(README의 실행 명령이 마운트).
const RESULT_DIR = __ENV.RESULT_DIR || '/results';

function seconds(duration) {
  const match = /^(\d+)(s|m)$/.exec(duration);
  if (!match) {
    throw new Error(`기간은 30s, 3m 형식입니다: ${duration}`);
  }
  return Number(match[1]) * (match[2] === 'm' ? 60 : 1);
}

function buildScenarios() {
  const scenarios = {};
  const thresholds = {};
  let start = 0;
  let totalVUs = 0;
  for (const rate of STAGES) {
    const name = `stage_${rate}`;
    const maxVUs = Math.max(5, rate * SESSION_SECONDS);
    totalVUs += maxVUs;
    scenarios[name] = {
      executor: 'constant-arrival-rate',
      rate,
      timeUnit: '1s',
      duration: STAGE_DURATION,
      startTime: `${start}s`,
      preAllocatedVUs: maxVUs,
      maxVUs,
      gracefulStop: '30s',
    };
    thresholds[`http_req_failed{scenario:${name}}`] = [{ threshold: 'rate<0.01', abortOnFail: true, delayAbortEval: '30s' }];
    thresholds[`http_req_duration{scenario:${name},operation:getDaily}`] = [{ threshold: 'p(95)<2000', abortOnFail: true, delayAbortEval: '30s' }];
    start += seconds(STAGE_DURATION) + seconds(STAGE_GAP);
  }
  return { scenarios, thresholds, totalVUs };
}

const built = buildScenarios();
// VU 하나가 계정 하나를 맡아, 같은 갱신 토큰을 두 VU가 함께 쓰지 않게 합니다(refresh rotation).
// VU는 단계(scenario)마다 따로라 계정 수는 가장 큰 단계가 아니라 모든 단계의 합입니다. 단계끼리 계정을 나눠 쓰면
// 앞 단계가 바꾼 갱신 토큰을 다음 VU가 몰라 테스트 로그인으로 대신하고, 그 요청이 측정에 섞입니다.
if (built.totalVUs > ACCOUNTS) {
  throw new Error(`VU ${built.totalVUs}개에 계정 ${ACCOUNTS}개가 모자랍니다. ACCOUNTS를 늘리고 accounts.js를 다시 돌리세요`);
}

export const options = {
  scenarios: built.scenarios,
  thresholds: built.thresholds,
  setupTimeout: '10m',
  // 304(getGlossary의 If-None-Match)는 k6 기본 성공 범위(200~399)라 http_req_failed에 들어가지 않습니다.
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

// setup은 쓸 계정 전부를 테스트 로그인해 갱신 토큰을 받습니다. 이 요청은 scenario tag가 없어 단계 집계에 들어가지 않습니다.
export function setup() {
  requireSecret();
  const refresh = [];
  const batchSize = 50;
  for (let start = 0; start < built.totalVUs; start += batchSize) {
    const labels = [];
    for (let i = start; i < Math.min(start + batchSize, built.totalVUs); i += 1) {
      labels.push(accountLabel(i));
    }
    const responses = api.sendAll(labels.map((label) => api.testLogin(label)));
    responses.forEach((res, offset) => {
      if (res.status !== 200) {
        throw new Error(`계정 ${start + offset} 로그인 실패(${res.status}). accounts.js를 먼저 돌렸는지 확인하세요`);
      }
      refresh.push(res.json().tokens.refreshToken);
    });
  }
  return { refresh };
}

// account는 VU마다 하나입니다. 처음 쓸 때 setup의 갱신 토큰으로 시작하고, 그 뒤로는 갱신 응답의 새 토큰을 씁니다.
let account = null;

export default function (data) {
  if (account === null) {
    const index = exec.vu.idInTest - 1;
    account = { label: accountLabel(index), refresh: data.refresh[index], glossaryEtag: '' };
  }
  session(account);
}

// handleSummary는 회차 요약을 씁니다. setup_data에는 갱신 토큰이 들어 있어 빼고 씁니다(결과 파일은 저장소에 남김, D104 ②).
export function handleSummary(data) {
  const { setup_data: _tokens, ...summary } = data;
  return {
    [`${RESULT_DIR}/k6-summary.json`]: JSON.stringify(summary, null, 2),
    stdout: `\n회차 요약을 ${RESULT_DIR}/k6-summary.json에 썼습니다.\n`,
  };
}
