package httpapi

import (
	"context"

	"github.com/june20516/myungli-diary/server/internal/city"
	"github.com/june20516/myungli-diary/server/internal/httpapi/gen"
)

// defaultCityLimit은 listCities limit의 기본값입니다(계약 default).
const defaultCityLimit = 20

// ListCities는 도시 이름 앞부분으로 도시를 찾습니다(P6-9). 로그인이 없고 입력을 저장하지 않습니다.
// lang이 없으면 Accept-Language로 고른 언어입니다. ETag는 "<도시 자료 버전>-<언어>"(강한 ETag)이며
// 같은 URL이면 자료 버전이 같을 때 결과도 같으므로 If-None-Match가 맞으면 본문 없이 304입니다.
func (a *API) ListCities(ctx context.Context, req gen.ListCitiesRequestObject) (gen.ListCitiesResponseObject, error) {
	lang := LanguageFrom(ctx)
	if req.Params.Lang != nil {
		lang = string(*req.Params.Lang)
	}
	limit := defaultCityLimit
	if req.Params.Limit != nil {
		limit = *req.Params.Limit
	}

	version := city.DataVersion()
	etag := `"` + version + "-" + lang + `"`
	if req.Params.IfNoneMatch != nil && etagMatches(*req.Params.IfNoneMatch, etag) {
		return gen.ListCities304Response{Headers: gen.NotModifiedResponseHeaders{ETag: &etag}}, nil
	}

	found := city.Search(req.Params.Q, lang, limit)
	items := make([]gen.City, 0, len(found))
	for _, c := range found {
		items = append(items, toCity(c, lang, c.Longitude))
	}
	return gen.ListCities200JSONResponse{
		Body:    gen.CityList{DataVersion: version, Items: items},
		Headers: gen.ListCities200ResponseHeaders{ETag: &etag},
	}, nil
}

// GetAppConfig는 플랫폼별 최소 앱 버전을 돌려줍니다(P6-10).
func (a *API) GetAppConfig(context.Context, gen.GetAppConfigRequestObject) (gen.GetAppConfigResponseObject, error) {
	return gen.GetAppConfig200JSONResponse{
		MinimumVersion: gen.MinimumVersion{Ios: a.AppConfig.MinIOS, Android: a.AppConfig.MinAndroid},
	}, nil
}
