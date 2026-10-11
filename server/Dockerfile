# 빌드 컨텍스트는 server/ 뿐이다(D56④).
# GO_VERSION 기본값은 go.mod의 go 지시어와 같아야 하고, CI는 go.mod 값을 넘긴다.
ARG GO_VERSION=1.27
FROM golang:${GO_VERSION} AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /server /server
ENTRYPOINT ["/server"]
CMD ["serve"]
