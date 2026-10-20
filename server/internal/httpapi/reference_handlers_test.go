package httpapi_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/june20516/myungli-diary/server/internal/city"
	"github.com/june20516/myungli-diary/server/internal/httpapi"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// getReference는 로그인 없는 참조 자료 요청을 보냅니다. headers는 이름, 값 순서의 쌍입니다.
func getReference(t *testing.T, target string, headers ...string) (*http.Request, *httptest.ResponseRecorder) {
	t.Helper()
	handler, _ := newHandlerAPI(t, &httpapi.API{AppConfig: httpapi.AppConfig{MinIOS: "1.2.0", MinAndroid: "3.4.5"}})
	req := httptest.NewRequestWithContext(t.Context(), http.MethodGet, target, nil)
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	return req, serve(handler, req)
}

func decodeCityList(t *testing.T, rec *httptest.ResponseRecorder) gen.CityList {
	t.Helper()
	var list gen.CityList
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &list))
	return list
}

func TestListCities_Returns200WithETagAndCityData(t *testing.T) {
	req, rec := getReference(t, "/v1/cities?q=Seoul&lang=ko")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.Equal(t, `"`+city.DataVersion()+`-ko"`, rec.Header().Get("ETag"))
	list := decodeCityList(t, rec)
	assert.Equal(t, city.DataVersion(), list.DataVersion)
	require.NotEmpty(t, list.Items)
	seoul := list.Items[0]
	assert.Equal(t, "1835848", seoul.Id)
	assert.Equal(t, "서울특별시", seoul.Name)
	assert.Equal(t, "대한민국", seoul.CountryName)
	assert.InDelta(t, 126.9784, seoul.Longitude, 1e-3, "경도는 도시 자료의 값")
}

func TestListCities_NoMatchIsEmptyArray(t *testing.T) {
	_, rec := getReference(t, "/v1/cities?q=zzzzqqqq")

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), `"items":[]`)
}

func TestListCities_LangFallsBackToAcceptLanguage(t *testing.T) {
	_, rec := getReference(t, "/v1/cities?q=Seoul", "Accept-Language", "ja;q=0.9, ko;q=0.8")

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, `"`+city.DataVersion()+`-ja"`, rec.Header().Get("ETag"))
	assert.Equal(t, "ソウル特別市", decodeCityList(t, rec).Items[0].Name)
}

func TestListCities_LangQueryBeatsAcceptLanguage(t *testing.T) {
	_, rec := getReference(t, "/v1/cities?q=Seoul&lang=en", "Accept-Language", "ko")

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "Seoul", decodeCityList(t, rec).Items[0].Name)
}

func TestListCities_LimitDefaultsTo20AndTruncates(t *testing.T) {
	_, rec := getReference(t, "/v1/cities?q=a")
	assert.Len(t, decodeCityList(t, rec).Items, 20)

	_, rec = getReference(t, "/v1/cities?q=a&limit=3")
	assert.Len(t, decodeCityList(t, rec).Items, 3)
}

func TestListCities_NotModifiedWhenETagMatches(t *testing.T) {
	etag := `"` + city.DataVersion() + `-en"`

	req, rec := getReference(t, "/v1/cities?q=Seoul", "If-None-Match", etag)

	require.Equal(t, http.StatusNotModified, rec.Code)
	expectFortuneContract(t, req, rec)
	assert.Equal(t, etag, rec.Header().Get("ETag"))
	assert.Empty(t, rec.Body.String())
}

func TestListCities_DifferentLanguageETagIsNotMatched(t *testing.T) {
	_, rec := getReference(t, "/v1/cities?q=Seoul&lang=ko", "If-None-Match", `"`+city.DataVersion()+`-en"`)

	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestListCities_InvalidQueryIsRejectedByContract(t *testing.T) {
	_, rec := getReference(t, "/v1/cities")
	expectInvalid(t, rec, "q")

	_, rec = getReference(t, "/v1/cities?q=Seoul&limit=51")
	expectInvalid(t, rec, "limit")
}

func TestGetAppConfig_ReturnsConfiguredMinimumVersions(t *testing.T) {
	req, rec := getReference(t, "/v1/app-config")

	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())
	expectFortuneContract(t, req, rec)
	assert.JSONEq(t, `{"minimumVersion":{"ios":"1.2.0","android":"3.4.5"}}`, rec.Body.String())
}
