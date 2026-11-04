// REST 계약(server/api/openapi.yaml) 형식의 요청입니다. 함수마다 http.batch에 넣을 수 있는 요청 객체를 만들고,
// send(하나)나 sendAll(동시에 여럿, app의 화면이 provider를 함께 구독하는 것과 같음)로 보냅니다.
// 요청마다 tag operation(operationId)을 붙여 결과 집계(stages.csv)가 요청 종류별로 나눕니다.
// name도 operationId로 두어 경로의 날짜와 id가 지표를 쪼개지 않게 합니다.

import http from 'k6/http';
import { BASE_URL, REQUEST_TIMEOUT, TEST_LOGIN_SECRET } from './config.js';

function request(operation, method, path, { token, body, headers = {} } = {}) {
  const allHeaders = { ...headers };
  if (token) {
    allHeaders.Authorization = `Bearer ${token}`;
  }
  if (body !== undefined) {
    allHeaders['Content-Type'] = 'application/json';
  }
  return {
    method,
    url: `${BASE_URL}${path}`,
    body: body === undefined ? null : JSON.stringify(body),
    params: { headers: allHeaders, timeout: REQUEST_TIMEOUT, tags: { operation, name: operation } },
  };
}

// send는 요청 하나를 보냅니다.
export function send(req) {
  return http.request(req.method, req.url, req.body, req.params);
}

// sendAll은 요청 여럿을 동시에 보내고 같은 순서로 응답을 돌려줍니다.
export function sendAll(reqs) {
  return http.batch(reqs);
}

// 테스트 로그인(S24). 비밀 헤더는 tag와 로그에 남지 않습니다.
export const testLogin = (label) =>
  request('testLogin', 'POST', '/test/v1/auth/login', { body: { label }, headers: { 'X-Test-Login-Secret': TEST_LOGIN_SECRET } });

export const refreshToken = (refresh) => request('refreshToken', 'POST', '/v1/auth/refresh', { body: { refreshToken: refresh } });
export const getAppConfig = () => request('getAppConfig', 'GET', '/v1/app-config');
export const getMe = (token) => request('getMe', 'GET', '/v1/me', { token });
export const agreeConsents = (token, documents) => request('agreeConsents', 'POST', '/v1/me/consents', { token, body: { documents } });
export const createProfile = (token, profile) => request('createProfile', 'PUT', '/v1/me/profile', { token, body: profile });
export const getDaily = (token, date) => request('getDaily', 'GET', `/v1/daily/${date}`, { token });
export const getChart = (token) => request('getChart', 'GET', '/v1/chart', { token });
export const getCalendar = (token, year, month) => request('getCalendar', 'GET', `/v1/calendar/${year}/${month}`, { token });
export const listSchedules = (token, from, to) => request('listSchedules', 'GET', `/v1/schedules?from=${from}&to=${to}`, { token });
export const listDiaries = (token, from, to) => request('listDiaries', 'GET', `/v1/diaries?from=${from}&to=${to}`, { token });
export const getDiary = (token, id) => request('getDiary', 'GET', `/v1/diaries/${id}`, { token });

// getGlossary는 app처럼 가진 ETag를 If-None-Match로 보냅니다. 같으면 304입니다.
export function getGlossary(token, etag) {
  return request('getGlossary', 'GET', '/v1/glossary', { token, headers: etag ? { 'If-None-Match': etag } : {} });
}

export function putReaction(token, date, slot) {
  return request('putReaction', 'PUT', `/v1/daily/${date}/slots/${slot}/reaction`, { token, body: { reaction: 'like' } });
}

// createDiary는 app처럼 Idempotency-Key를 붙입니다(createDiary 멱등).
export function createDiary(token, date, body, idempotencyKey) {
  return request('createDiary', 'POST', '/v1/diaries', { token, body: { date, body }, headers: { 'Idempotency-Key': idempotencyKey } });
}
