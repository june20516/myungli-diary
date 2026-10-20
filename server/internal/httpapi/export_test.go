package httpapi

// WithAccount는 외부 테스트 패키지(httpapi_test)가 인증을 거친 것처럼 ctx에 계정을 넣을 때 씁니다.
var WithAccount = withAccount

// ToChartForTest는 외부 테스트 패키지가 toChart(View -> 계약 Chart)를 직접 확인할 때 씁니다.
var ToChartForTest = toChart
