// 테스트 계정 준비입니다(L1 plan L1-2 Step 3). 회차마다 DB를 새로 만들므로(load-teardown) 측정 전에 한 번 돌립니다.
// 계정 번호 0..ACCOUNTS-1마다 테스트 로그인 → 동의(getMe의 requiredConsents를 그대로) → 프로필 저장을 합니다.
// 같은 번호는 같은 계정, 같은 프로필이라 다시 돌려도 됩니다. 이 실행의 요청은 측정 결과에 넣지 않습니다.
//
// 실행: README "계정 만들기"

import exec from 'k6/execution';
import { check, fail } from 'k6';
import * as api from './lib/api.js';
import { ACCOUNTS, accountLabel, intEnv, requireSecret } from './lib/config.js';
import { profileFor } from './lib/profiles.js';

export const options = {
  scenarios: {
    accounts: {
      executor: 'shared-iterations',
      vus: intEnv('ACCOUNT_VUS', 20),
      iterations: ACCOUNTS,
      maxDuration: '30m',
    },
  },
  thresholds: {
    // 계정 하나라도 준비에 실패하면 실행을 실패로 끝냅니다. 측정 전에 다시 돌립니다.
    checks: ['rate==1'],
  },
};

export function setup() {
  requireSecret();
}

export default function () {
  const index = exec.scenario.iterationInTest;
  const login = api.send(api.testLogin(accountLabel(index)));
  if (!check(login, { 'testLogin 200': (r) => r.status === 200 })) {
    fail(`계정 ${index} 로그인 실패: ${login.status}`);
  }
  const token = login.json().tokens.accessToken;

  const me = api.send(api.getMe(token));
  const required = me.json().requiredConsents || [];
  if (required.length > 0) {
    const documents = required.map((d) => ({ document: d.document, version: d.version }));
    check(api.send(api.agreeConsents(token, documents)), { 'agreeConsents 204': (r) => r.status === 204 });
  }
  check(api.send(api.createProfile(token, profileFor(index))), { 'createProfile 2xx': (r) => r.status === 200 || r.status === 201 });
}
