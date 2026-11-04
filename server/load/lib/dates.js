// 날짜 계산입니다. 계정 시간대(Asia/Seoul, UTC+9, 서머타임 없음) 기준 날짜를 YYYY-MM-DD로 씁니다.

const SEOUL_OFFSET_MS = 9 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

// seoulDate는 지금으로부터 offsetDays일 뒤의 서울 날짜입니다(음수면 과거).
export function seoulDate(offsetDays = 0) {
  const shifted = new Date(Date.now() + SEOUL_OFFSET_MS + offsetDays * DAY_MS);
  return shifted.toISOString().slice(0, 10);
}

// yearMonth는 YYYY-MM-DD에서 연도와 월을 꺼냅니다.
export function yearMonth(isoDate) {
  return { year: Number(isoDate.slice(0, 4)), month: Number(isoDate.slice(5, 7)) };
}

// calendarGrid는 app 캘린더의 42칸(일요일 시작 6주) 범위입니다. app은 이 범위로 listSchedules, listDiaries를 부릅니다.
export function calendarGrid(isoDate) {
  const { year, month } = yearMonth(isoDate);
  const first = new Date(Date.UTC(year, month - 1, 1));
  const start = new Date(first.getTime() - first.getUTCDay() * DAY_MS);
  const end = new Date(start.getTime() + 41 * DAY_MS);
  return { from: start.toISOString().slice(0, 10), to: end.toISOString().slice(0, 10) };
}

// neighborMonths는 app이 캘린더 탭에서 받는 앞 달, 이번 달, 다음 달입니다.
export function neighborMonths(isoDate) {
  const { year, month } = yearMonth(isoDate);
  return [-1, 0, 1].map((delta) => {
    const shifted = new Date(Date.UTC(year, month - 1 + delta, 1));
    return { year: shifted.getUTCFullYear(), month: shifted.getUTCMonth() + 1 };
  });
}
