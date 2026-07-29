FROM golang:1.23-alpine AS build

WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/unraid-exporter .

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/unraid-exporter /unraid-exporter
EXPOSE 9108
USER nonroot:nonroot
ENTRYPOINT ["/unraid-exporter"]
