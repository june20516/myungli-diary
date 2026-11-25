package fortune

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/june20516/myungli-diary/server/internal/content"
	"github.com/june20516/myungli-diary/server/internal/engine"
	"github.com/june20516/myungli-diary/server/internal/platform/clock"
	"github.com/june20516/myungli-diary/server/internal/profile"
	"github.com/june20516/myungli-diary/server/seed"
)

// 조합 확인(smoke, D147 ①, S169)은 배포 뒤 그 환경의 server 코드, 엔진, 활성 시드가 함께 화면 문장을 끝까지 만드는지 봅니다.
// 실제 화면 조립(Views)을 그대로 타되, 고정된 출생 정보로 돌고 계정, 선택 기록, 결과 캐시를 만들지 않습니다.
// 렌더 실패는 Renderer와 Views가 Error 로그로만 남기므로(호출자에게 오류를 돌려주지 않음), 그 로그를 모아 실패로 셉니다.

// smokeTimezone은 조합 확인의 현재 시간대입니다. 오늘 날짜도 이 시간대로 정합니다.
const smokeTimezone = "Asia/Seoul"

// smokeVariantRounds는 순환 변주를 모두 렌더하려고 오늘 화면을 몇 번 조립할지입니다. 가장 긴 순환(문장 유형 셋)과 같습니다.
var smokeVariantRounds = len(content.RotationVariants(seed.RotationType))

// SmokeStore는 조합 확인이 읽는 콘텐츠 저장소입니다. 읽기만 하고 선택 기록을 쓰지 않습니다.
type SmokeStore interface {
	Active(ctx context.Context) (string, error)
	Templates(ctx context.Context, version, lang string) (content.Templates, error)
	Glossary(ctx context.Context, version, lang string) (content.Glossary, error)
	Slots(ctx context.Context, version string) (map[string]seed.Slot, error)
}

var _ SmokeStore = (*content.Store)(nil)

// SmokeConfig는 조합 확인 설정입니다.
type SmokeConfig struct {
	Engine engine.Engine
	Store  SmokeStore
	Clock  clock.Clock
	// Logger는 렌더 실패 로그를 그대로 흘려 보낼 곳입니다. nil이면 버립니다.
	Logger *slog.Logger
	// Languages는 확인할 언어입니다. 비면 SmokeLanguages입니다.
	Languages []string
}

// SmokeLanguages는 앱이 지원하는 언어입니다(D27).
var SmokeLanguages = []string{"ko", "en", "ja"}

// SmokeFailure는 문장을 만들지 못한 일 하나입니다. Attrs는 실패 로그의 칸(slot, key, variant, lang, error)입니다.
// 고정된 시험 출생 정보만 쓰므로 개인정보가 없습니다.
type SmokeFailure struct {
	Message string
	Attrs   map[string]string
}

// SmokeReport는 조합 확인 결과입니다. Checks는 조립해 본 화면 수입니다.
type SmokeReport struct {
	Checks   int
	Failures []SmokeFailure
}

// smokeBirths는 시험 출생 정보입니다. 태어난 시간을 아는 경우와 모르는 경우(낮 12시 계산 안내)를 함께 봅니다.
func smokeBirths() []profile.Birth {
	return []profile.Birth{
		{
			Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1990, Month: 5, Day: 17},
			TimeStatus: profile.TimeKnown, Time: &profile.LocalTime{Hour: 8, Minute: 30},
			Gender: "female", Timezone: smokeTimezone, PlaceStatus: profile.PlaceNotAsked,
		},
		{
			Calendar: profile.CalendarSolar, Date: profile.LocalDate{Year: 1985, Month: 11, Day: 2},
			TimeStatus: profile.TimeUnknown, Gender: "male", Timezone: smokeTimezone, PlaceStatus: profile.PlaceNotAsked,
		},
	}
}

// smokeHonorifics는 언어별 시험 호칭입니다. 호칭 슬롯의 조사 처리까지 렌더하려고 언어마다 둡니다.
var smokeHonorifics = map[string]string{"ko": "민지", "en": "Alex", "ja": "ゆき"}

// RunSmoke는 언어마다, 시험 출생 정보마다, 근거 열람 잠김과 열림 둘 다로 오늘(순환 변주 전부), 달력, 나의 사주 화면을 조립합니다.
// 엔진이나 저장소 호출이 실패하면 오류를 돌려주고, 문장을 만들지 못한 일은 SmokeReport.Failures에 담습니다.
func RunSmoke(ctx context.Context, cfg SmokeConfig) (SmokeReport, error) {
	langs := cfg.Languages
	if len(langs) == 0 {
		langs = SmokeLanguages
	}
	recorder := &failureRecorder{}
	next := slog.DiscardHandler
	if cfg.Logger != nil {
		next = cfg.Logger.Handler()
	}
	log := slog.New(recordingHandler{next: next, sink: recorder})

	versions := engine.NewVersions(cfg.Engine, log)
	if err := versions.Refresh(ctx); err != nil {
		return SmokeReport{}, fmt.Errorf("엔진 규칙 버전 조회: %w", err)
	}
	service := NewService(cfg.Engine, versions, newMemoryCache(), log)
	renderer := content.NewRenderer(log)

	today, err := localToday(cfg.Clock, smokeTimezone)
	if err != nil {
		return SmokeReport{}, err
	}
	report := SmokeReport{}
	for _, lang := range langs {
		for _, birth := range smokeBirths() {
			p := profile.Profile{Honorific: smokeHonorifics[lang], Language: lang, CurrentTimezone: smokeTimezone, Birth: birth}
			for _, unlocked := range []bool{false, true} {
				for round := range smokeVariantRounds {
					views := NewViews(service, &dryRunStore{SmokeStore: cfg.Store, round: round}, renderer, fixedInsight(unlocked), cfg.Clock, log)
					if _, err := views.Daily(ctx, uuid.Nil, p, today); err != nil {
						return report, fmt.Errorf("오늘 화면(%s): %w", lang, err)
					}
					report.Checks++
				}
				views := NewViews(service, &dryRunStore{SmokeStore: cfg.Store}, renderer, fixedInsight(unlocked), cfg.Clock, log)
				if _, err := views.Calendar(ctx, uuid.Nil, p, today.Year, today.Month); err != nil {
					return report, fmt.Errorf("달력(%s): %w", lang, err)
				}
				if _, err := views.Chart(ctx, uuid.Nil, p); err != nil {
					return report, fmt.Errorf("나의 사주(%s): %w", lang, err)
				}
				report.Checks += 2
			}
		}
	}
	report.Failures = recorder.failures()
	return report, nil
}

func localToday(clk clock.Clock, timezone string) (profile.LocalDate, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return profile.LocalDate{}, fmt.Errorf("시간대 %s: %w", timezone, err)
	}
	now := clk.Now().In(loc)
	return profile.LocalDate{Year: now.Year(), Month: int(now.Month()), Day: now.Day()}, nil
}

// fixedInsight는 정해진 근거 열람 권한을 돌려줍니다.
type fixedInsight bool

func (f fixedInsight) Unlocked(context.Context, uuid.UUID) (bool, error) { return bool(f), nil }

// dryRunStore는 선택 기록을 쓰지 않는 ContentStore입니다. 슬롯마다 활성 시드 명세의 순환 변주 가운데 round번째를 고릅니다.
// 순환 차례와 돌봄 상한은 사용자 기록에 따른 것이라 여기서는 보지 않고, 모든 변주가 렌더되는지만 봅니다.
type dryRunStore struct {
	SmokeStore
	round int
}

func (s *dryRunStore) Select(ctx context.Context, _ uuid.UUID, _ time.Time, _ [32]byte, reqs []content.SlotRequest) ([]content.Selection, error) {
	version, err := s.Active(ctx)
	if err != nil {
		return nil, err
	}
	slots, err := s.Slots(ctx, version)
	if err != nil {
		return nil, err
	}
	out := make([]content.Selection, 0, len(reqs))
	for _, r := range reqs {
		spec, ok := slots[r.Slot]
		if !ok {
			return nil, fmt.Errorf("시드 %s의 슬롯 명세에 없는 슬롯입니다: %s", version, r.Slot)
		}
		variants := content.RotationVariants(spec.Rotation)
		if len(variants) == 0 {
			return nil, fmt.Errorf("슬롯 %s의 순환 방식을 모릅니다: %s", r.Slot, spec.Rotation)
		}
		out = append(out, content.Selection{
			Slot: r.Slot, MessageKey: r.MessageKey, Variant: variants[s.round%len(variants)], SeedVersion: version,
		})
	}
	return out, nil
}

// memoryCache는 한 번의 조합 확인 안에서만 쓰는 결과 캐시입니다. DB 캐시를 쓰지 않아야 배포된 엔진을 실제로 부릅니다.
// 같은 입력을 여러 화면이 다시 쓸 때 엔진을 한 번만 부르려고 둡니다.
type memoryCache struct {
	mu      sync.Mutex
	entries map[any][]byte
}

func newMemoryCache() *memoryCache { return &memoryCache{entries: map[any][]byte{}} }

func (c *memoryCache) get(k any) ([]byte, bool, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	b, ok := c.entries[k]
	return b, ok, nil
}

func (c *memoryCache) put(k any, b []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[k] = b
	return nil
}

func (c *memoryCache) GetChart(_ context.Context, k ChartKey) ([]byte, bool, error) { return c.get(k) }
func (c *memoryCache) PutChart(_ context.Context, k ChartKey, b []byte) error       { return c.put(k, b) }
func (c *memoryCache) GetDaily(_ context.Context, k DailyKey) ([]byte, bool, error) { return c.get(k) }
func (c *memoryCache) PutDaily(_ context.Context, k DailyKey, b []byte) error       { return c.put(k, b) }
func (c *memoryCache) GetMonth(_ context.Context, k MonthKey) ([]byte, bool, error) { return c.get(k) }
func (c *memoryCache) PutMonth(_ context.Context, k MonthKey, b []byte) error       { return c.put(k, b) }

// failureRecorder는 Error 이상 로그를 실패로 모읍니다.
type failureRecorder struct {
	mu   sync.Mutex
	list []SmokeFailure
}

func (r *failureRecorder) add(f SmokeFailure) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.list = append(r.list, f)
}

func (r *failureRecorder) failures() []SmokeFailure {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]SmokeFailure(nil), r.list...)
}

// recordingHandler는 Error 이상 로그를 sink에 적고 next에도 그대로 넘깁니다.
type recordingHandler struct {
	next  slog.Handler
	sink  *failureRecorder
	attrs []slog.Attr
}

func (h recordingHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return level >= slog.LevelError || h.next.Enabled(ctx, level)
}

func (h recordingHandler) Handle(ctx context.Context, r slog.Record) error {
	if r.Level >= slog.LevelError {
		attrs := make(map[string]string, len(h.attrs)+r.NumAttrs())
		for _, a := range h.attrs {
			attrs[a.Key] = a.Value.String()
		}
		r.Attrs(func(a slog.Attr) bool {
			attrs[a.Key] = a.Value.String()
			return true
		})
		h.sink.add(SmokeFailure{Message: r.Message, Attrs: attrs})
	}
	if !h.next.Enabled(ctx, r.Level) {
		return nil
	}
	return h.next.Handle(ctx, r)
}

func (h recordingHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return recordingHandler{next: h.next.WithAttrs(attrs), sink: h.sink, attrs: append(append([]slog.Attr(nil), h.attrs...), attrs...)}
}

// WithGroup은 그룹 이름을 무시하고 칸 이름만 모읍니다. 실패 로그는 그룹을 쓰지 않습니다.
func (h recordingHandler) WithGroup(name string) slog.Handler {
	return recordingHandler{next: h.next.WithGroup(name), sink: h.sink, attrs: h.attrs}
}
