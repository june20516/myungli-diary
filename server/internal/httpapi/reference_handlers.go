package httpapi

import (
	"context"
	"errors"
	"net/http"

	"github.com/june20516/myungli-diary/server/internal/city"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
	"github.com/june20516/myungli-diary/server/legal"
)

// defaultCityLimit은 listCities limit의 기본값입니다(계약 default).
const defaultCityLimit = 20

// ListCities는 도시 이름 앞부분으로 도시를 찾습니다(P6-9). 로그인이 없고 입력을 저장하지 않습니다.
// lang이 없으면 Accept-Language로 고른 언어입니다. ETag는 "<도시 자료 버전>-<언어>"(강한 ETag)이며
// 같은 URL이면 자료 버전이 같을 때 결과도 같으므로 If-None-Match가 맞으면 본문 없이 304입니다.
func (a *API) ListCities(ctx context.Context, req gen.ListCitiesRequestObject) (gen.ListCitiesResponseObject, error) {
	lang := LanguageFrom(ctx)
	langFromHeader := req.Params.Lang == nil
	if !langFromHeader {
		lang = string(*req.Params.Lang)
	}
	limit := defaultCityLimit
	if req.Params.Limit != nil {
		limit = *req.Params.Limit
	}

	version := city.DataVersion()
	etag := `"` + version + "-" + lang + `"`
	if req.Params.IfNoneMatch != nil && etagMatches(*req.Params.IfNoneMatch, etag) {
		return varyByLanguage(gen.ListCities304Response{Headers: gen.NotModifiedResponseHeaders{ETag: &etag}}, langFromHeader), nil
	}

	found := city.Search(req.Params.Q, lang, limit)
	items := make([]gen.City, 0, len(found))
	for _, c := range found {
		items = append(items, toCity(c, lang, c.Longitude))
	}
	return varyByLanguage(gen.ListCities200JSONResponse{
		Body:    gen.CityList{DataVersion: version, Items: items},
		Headers: gen.ListCities200ResponseHeaders{ETag: &etag},
	}, langFromHeader), nil
}

// vary는 응답에 Vary: Accept-Language를 더해 쓰는 listCities 응답입니다.
type vary struct{ gen.ListCitiesResponseObject }

func (v vary) VisitListCitiesResponse(w http.ResponseWriter) error {
	w.Header().Add("Vary", "Accept-Language")
	return v.ListCitiesResponseObject.VisitListCitiesResponse(w)
}

// varyByLanguage는 언어를 Accept-Language로 골랐을 때만 Vary: Accept-Language를 붙입니다. lang 쿼리면 URL이 언어를 정합니다.
func varyByLanguage(resp gen.ListCitiesResponseObject, langFromHeader bool) gen.ListCitiesResponseObject {
	if !langFromHeader {
		return resp
	}
	return vary{resp}
}

// GetAppConfig는 플랫폼별 최소 앱 버전(P6-10)과 법적 문서 주소(D80)를 돌려줍니다.
// 법적 문서는 App Link와 같은 서비스 도메인(AppLink.Base)에서 내줍니다.
func (a *API) GetAppConfig(context.Context, gen.GetAppConfigRequestObject) (gen.GetAppConfigResponseObject, error) {
	if a.AppLink.Base == nil {
		return nil, errors.New("AppLink.Base가 없어 법적 문서 주소를 만들 수 없습니다")
	}
	return gen.GetAppConfig200JSONResponse{
		MinimumVersion: gen.MinimumVersion{Ios: a.AppConfig.MinIOS, Android: a.AppConfig.MinAndroid},
		Legal: gen.LegalLinks{
			Terms:   legalURL(a.AppLink.Base, legal.Terms),
			Privacy: legalURL(a.AppLink.Base, legal.Privacy),
		},
	}, nil
}
