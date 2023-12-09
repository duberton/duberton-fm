# duberton-fm

### media-player-track-message-bus

Local py app that starts up with the machine and listens to Strawberry events propagated by Linux D-Bus

1. Environment variables:
    
- API_GW_ENDPOINT: API Gateway DNS
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

### lambda-track-processor

Building the Go AWS Lambda

`GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -o ./bin/main main.go`

### infrastructure

- terraform apply -auto-approve