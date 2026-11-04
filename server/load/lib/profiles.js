// 테스트 계정의 프로필입니다. 출생 정보를 계정 번호로 고루 나눠, 엔진 결과 캐시(사주 지문, S26)가 한 사주로 몰리지 않게 합니다.
// 같은 번호는 늘 같은 프로필이라 accounts.js를 다시 돌려도 결과가 같습니다(createProfile은 PUT 멱등, S25).

import { TIMEZONE } from './config.js';

export function profileFor(index) {
  const year = 1950 + ((index * 7) % 56); // 1950~2005
  const month = 1 + ((index * 5) % 12);
  const day = 1 + ((index * 11) % 28); // 모든 달에 있는 날만
  const minutes = (index * 37) % 1440;
  const time = index % 4 === 0
    ? { status: 'unknown' }
    : { status: 'known', value: `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}` };
  return {
    honorific: `계정${index}`,
    language: 'ko',
    currentTimezone: TIMEZONE,
    birth: {
      calendar: 'solar',
      date: { year, month, day },
      isLeapMonth: false,
      time,
      gender: index % 2 === 0 ? 'female' : 'male',
      timezone: TIMEZONE,
      place: { status: 'not_asked' },
    },
    // 알림 기기를 등록하지 않으므로 알림은 끕니다(notify Job도 측정 중 멈춤).
    notification: { status: 'disabled' },
  };
}
