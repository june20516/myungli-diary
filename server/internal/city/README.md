# internal/city

출생지 도시 자료(경도·시간대·언어별 이름)를 바이너리에 내장하고 geonameid로 조회합니다.

## 출처와 라이선스

* 원본: GeoNames, https://www.geonames.org/ (https://download.geonames.org/export/dump/)
* 라이선스: Creative Commons Attribution 4.0 (CC BY 4.0). 출처 표기: "GeoNames, https://www.geonames.org/"
* 받은 날짜: 2026-10-15

| 원본 파일 | 용도 |
| --- | --- |
| `cities15000.zip` | 인구 15,000명 이상 도시(id, 경도, 시간대, 나라, 1차 행정구역 코드) |
| `countryInfo.txt` | 나라 코드 → 나라 geonameid·영어 이름 |
| `admin1CodesASCII.txt` | 1차 행정구역 코드 → geonameid·이름 |
| `alternateNamesV2.zip` | ko·en·ja 이름(수백 MB, 생성기가 zip 안 txt를 스트리밍으로 읽음) |

## 이름 선택 규칙

`isolanguage`가 정확히 `ko`·`en`·`ja`인 이름 중 `isHistoric`·`isColloquial`이 아닌 것에서, `isPreferredName`인 첫 값을 먼저 쓰고 없으면 `isShortName`이 아닌 첫 값을 씁니다(파일 순서 기준). 그래도 없으면 en, en도 없으면 GeoNames 기본 이름입니다. 그래서 서울의 ko는 "서울특별시"(preferred), 도쿄의 ja는 "東京都"(preferred)입니다.

## 자료 다시 만들기 (수동)

원본이 저장소에 없어 CI에서 돌 수 없으므로 `go:generate`에 넣지 않습니다. 원본을 한 디렉터리(git 밖)에 받은 뒤 `server/`에서 실행합니다.

```sh
SRC=/path/to/geonames
for f in cities15000.zip countryInfo.txt admin1CodesASCII.txt alternateNamesV2.zip; do
  curl -fLO --output-dir "$SRC" "https://download.geonames.org/export/dump/$f"
done
go run ./internal/city/cmd/build \
  -cities "$SRC/cities15000.zip" -countries "$SRC/countryInfo.txt" \
  -admin1 "$SRC/admin1CodesASCII.txt" -alternates "$SRC/alternateNamesV2.zip" \
  -out internal/city/data/cities.json.gz
```

같은 원본이면 결과가 바이트 단위로 같습니다(정렬된 키, gzip header의 mtime 0·이름 없음, 도시는 영어 이름 순). 다시 만들면 `DataVersion()`이 바뀌고, 이 날짜와 위 표를 함께 갱신합니다.
