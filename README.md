# duberton-fm

### media-player-track-message-bus

1. Environment variables:
    
- API_GW_ENDPOINT: API Gateway execute api DNS

### lambda-track-processor

Building the Go AWS Lambda

`GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -o ./bin/main main.go`