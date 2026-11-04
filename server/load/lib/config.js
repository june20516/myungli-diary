// 부하 스크립트의 실행 설정입니다(L1 plan §1, §4). 값은 모두 환경 변수(k6 -e)로 받고, 비밀은 저장소와 로그에 남기지 않습니다.

// BASE_URL은 공개 주소입니다(Firebase Hosting, S135). 직접 주소(run.app)로 보내지 않습니다.
export const BASE_URL = (__ENV.BASE_URL || 'https://myungli-diary-load.web.app').replace(/\/$/, '');

// TEST_LOGIN_SECRET은 테스트 로그인(S24) 비밀 헤더 값입니다. 실행 명령이 Secret Manager에서 읽어 넘깁니다.
export const TEST_LOGIN_SECRET = __ENV.TEST_LOGIN_SECRET || '';

// LABEL_PREFIX는 테스트 계정 label 앞부분입니다. label은 영숫자 1~32자라 prefix도 영숫자만 씁니다.
export const LABEL_PREFIX = __ENV.LABEL_PREFIX || 'lt';

// ACCOUNTS는 미리 만들어 둔 테스트 계정 수입니다(accounts.js와 같은 값). VU 하나가 계정 하나를 맡습니다.
export const ACCOUNTS = intEnv('ACCOUNTS', 3200);

// TIMEZONE은 테스트 계정의 현재 시간대이자 "오늘"을 정하는 기준입니다.
export const TIMEZONE = 'Asia/Seoul';

// REQUEST_TIMEOUT은 요청 하나의 시간 초과입니다. 넘으면 k6가 status 0으로 기록합니다(한계 응답, plan §4).
export const REQUEST_TIMEOUT = __ENV.REQUEST_TIMEOUT || '30s';

export function intEnv(name, fallback) {
  const raw = __ENV[name];
  if (raw === undefined || raw === '') {
    return fallback;
  }
  const value = Number.parseInt(raw, 10);
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`${name}는 0 이상의 정수여야 합니다`);
  }
  return value;
}

export function requireSecret() {
  if (TEST_LOGIN_SECRET === '') {
    throw new Error('TEST_LOGIN_SECRET이 비어 있습니다. README의 실행 명령으로 Secret Manager에서 넘기세요');
  }
}

// label은 계정 번호로 정합니다. 같은 번호는 회차가 달라도 같은 계정입니다(테스트 로그인이 label로 계정을 찾음).
export function accountLabel(index) {
  return `${LABEL_PREFIX}${index}`;
}
