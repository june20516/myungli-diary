package render

import (
	"strings"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"
)

// 한글 음절 산식 상수입니다. 음절 = 0xAC00 + (초성*21 + 중성)*28 + 종성 이고,
// 종성 0은 받침 없음, 8은 ㄹ 받침입니다.
const (
	hangulFirst     = 0xAC00
	hangulLast      = 0xD7A3
	jongseongCount  = 28
	jongseongRieul  = 8
	maxTrailingZero = 4
)

// batchim은 마지막 글자의 받침 종류입니다.
type batchim int

const (
	batchimUnknown batchim = iota // 판정 불가
	batchimNone                   // 받침 없음
	batchimRieul                  // ㄹ 받침
	batchimOther                  // 그 밖의 받침
)

// josaPair는 조사 표기 한 쌍과 받침별 결과입니다. 원본은 rules/josa.yaml의 pairs이며,
// TestJosa_Examples가 이 표와 YAML이 어긋나지 않는지 확인합니다.
type josaPair struct {
	marker, withBatchim, withoutBatchim, rieul, fallback string
}

// josaPairs의 marker는 모두 "("로 시작하고 서로 접두어가 아닙니다.
var josaPairs = []josaPair{
	{marker: "(이)가", withBatchim: "이", withoutBatchim: "가", fallback: "이(가)"},
	{marker: "(은)는", withBatchim: "은", withoutBatchim: "는", fallback: "은(는)"},
	{marker: "(을)를", withBatchim: "을", withoutBatchim: "를", fallback: "을(를)"},
	{marker: "(과)와", withBatchim: "과", withoutBatchim: "와", fallback: "과(와)"},
	{marker: "(으)로", withBatchim: "으로", withoutBatchim: "로", rieul: "로", fallback: "(으)로"},
	{marker: "(이)에요", withBatchim: "이에요", withoutBatchim: "예요", fallback: "(이)에요"},
}

// 숫자 읽기 표입니다(rules/josa.yaml의 readings.digits, trailing_zeros).
var (
	digitReadings = map[rune]string{
		'0': "영", '1': "일", '2': "이", '3': "삼", '4': "사",
		'5': "오", '6': "육", '7': "칠", '8': "팔", '9': "구",
	}
	// 인덱스는 끝에서 연속한 0의 개수(1~4)입니다.
	trailingZeroReadings = [maxTrailingZero + 1]string{"", "십", "백", "천", "만"}
)

// latinReadings는 영문 대문자의 알파벳 이름 읽기입니다(readings.latin).
var latinReadings = map[rune]string{
	'A': "에이", 'B': "비", 'C': "씨", 'D': "디", 'E': "이", 'F': "에프", 'G': "지",
	'H': "에이치", 'I': "아이", 'J': "제이", 'K': "케이", 'L': "엘", 'M': "엠", 'N': "엔",
	'O': "오", 'P': "피", 'Q': "큐", 'R': "알", 'S': "에스", 'T': "티", 'U': "유", 'V': "브이",
	'W': "더블유", 'X': "엑스", 'Y': "와이", 'Z': "제트",
}

// hanjaReadings는 천간 10자와 지지 12자의 읽기입니다(readings.hanja).
var hanjaReadings = map[rune]string{
	'甲': "갑", '乙': "을", '丙': "병", '丁': "정", '戊': "무", '己': "기", '庚': "경", '辛': "신", '壬': "임", '癸': "계",
	'子': "자", '丑': "축", '寅': "인", '卯': "묘", '辰': "진", '巳': "사", '午': "오", '未': "미", '申': "신", '酉': "유", '戌': "술", '亥': "해",
}

// Josa는 문장 속 조사 표기 6쌍(예 "남색(이)가")을 바로 앞 글자의 받침에 맞게 바꿉니다.
// 입력은 먼저 NFC로 정규화합니다. 앞 글자의 받침을 판정할 수 없으면 병기형을 씁니다.
func Josa(s string) string {
	out, _ := renderJosa(norm.NFC.String(s))
	return out
}

// edit는 조사 치환 한 건입니다. 입력 s의 [oldStart, oldEnd) 구간이 newLen 바이트로 바뀝니다.
type edit struct {
	oldStart, oldEnd, newLen int
}

// renderJosa는 s(이미 NFC)의 조사 표기를 모두 바꾸고 치환 목록을 함께 돌려줍니다.
// 받침 판정은 매번 치환 전 원문의 앞부분을 기준으로 합니다.
func renderJosa(s string) (string, []edit) {
	var (
		out   strings.Builder
		edits []edit
	)
	for i := 0; i < len(s); {
		pair, ok := matchPair(s[i:])
		if !ok {
			out.WriteByte(s[i])
			i++
			continue
		}
		repl := chooseJosa(pair, finalBatchim(s[:i]))
		out.WriteString(repl)
		edits = append(edits, edit{oldStart: i, oldEnd: i + len(pair.marker), newLen: len(repl)})
		i += len(pair.marker)
	}
	return out.String(), edits
}

// matchPair는 s가 조사 표기로 시작하면 그 쌍을 돌려줍니다.
func matchPair(s string) (josaPair, bool) {
	if !strings.HasPrefix(s, "(") {
		return josaPair{}, false
	}
	for _, p := range josaPairs {
		if strings.HasPrefix(s, p.marker) {
			return p, true
		}
	}
	return josaPair{}, false
}

// chooseJosa는 받침 종류에 맞는 조사를 고릅니다.
func chooseJosa(p josaPair, b batchim) string {
	switch {
	case b == batchimUnknown:
		return p.fallback
	case b == batchimNone:
		return p.withoutBatchim
	case b == batchimRieul && p.rieul != "":
		return p.rieul
	default:
		return p.withBatchim
	}
}

// hangulBatchim은 한글 음절의 받침을 계산합니다. 한글 음절이 아니면 batchimUnknown입니다.
func hangulBatchim(r rune) batchim {
	if r < hangulFirst || r > hangulLast {
		return batchimUnknown
	}
	switch (r - hangulFirst) % jongseongCount {
	case 0:
		return batchimNone
	case jongseongRieul:
		return batchimRieul
	default:
		return batchimOther
	}
}

// finalBatchim은 text(NFC)의 마지막 글자를 읽는 소리 기준으로 받침을 판정합니다.
// 한글은 직접, ASCII 숫자·영문과 천간지지 한자는 읽기 표로, 그 밖은 판정 불가입니다.
func finalBatchim(text string) batchim {
	last, size := utf8.DecodeLastRuneInString(text)
	if size == 0 {
		return batchimUnknown
	}
	if b := hangulBatchim(last); b != batchimUnknown {
		return b
	}
	reading := readingOf(text, last)
	if reading == "" {
		return batchimUnknown
	}
	r, _ := utf8.DecodeLastRuneInString(reading)
	return hangulBatchim(r)
}

// readingOf는 마지막 글자 last의 한글 읽기를 돌려줍니다. 읽을 수 없으면 빈 문자열입니다.
func readingOf(text string, last rune) string {
	switch {
	case last >= '0' && last <= '9':
		return numberReading(text)
	case last >= 'a' && last <= 'z':
		return latinReadings[last-'a'+'A']
	case last >= 'A' && last <= 'Z':
		return latinReadings[last]
	default:
		return hanjaReadings[last]
	}
}

// numberReading은 text 끝의 숫자 덩어리를 한 수로 보고 읽기를 돌려줍니다.
// 끝자리가 0이 아니면 그 숫자를, 전부 0이면 "영"을, 끝에 0이 이어지면 0의 개수별 자릿수 읽기를 씁니다.
func numberReading(text string) string {
	start := len(text)
	for start > 0 && text[start-1] >= '0' && text[start-1] <= '9' {
		start--
	}
	number := text[start:]
	zeros := len(number) - len(strings.TrimRight(number, "0"))
	if zeros == 0 || zeros == len(number) {
		return digitReadings[rune(number[len(number)-1])]
	}
	return trailingZeroReadings[min(zeros, maxTrailingZero)]
}
