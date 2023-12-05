package main

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

const (
	tableName = "duberton-fm"
)

// Item represents the data structure to be stored in DynamoDB.
type Item struct {
	Pk        string `dynamodbav:"pk"`
	Sk        string `dynamodbav:"sk"`
	Timestamp string `dynamodbav:"timestamp"`
}

type Song struct {
	Artist string `json:"artist"`
	Title  string `json:"title"`
}

func handler(ctx context.Context, event events.SQSEvent) (events.SQSEventResponse, error) {
	failures := []events.SQSBatchItemFailure{}

	cfg, _ := config.LoadDefaultConfig(ctx)

	var song Song

	for _, record := range event.Records {
		if err := json.Unmarshal([]byte(record.Body), &song); err != nil {
			failures = append(failures, events.SQSBatchItemFailure{ItemIdentifier: record.MessageId})
		}

		log.Printf("Received record to track with the following body %s and message id %s", record.Body, record.MessageId)

		client := dynamodb.NewFromConfig(cfg)

		item := Item{
			Pk:        song.Artist,
			Sk:        song.Title,
			Timestamp: time.Now().Format(time.RFC3339),
		}

		av, err := attributevalue.MarshalMap(item)

		log.Printf("Attribute Value: %v", av)

		if err != nil {
			log.Printf("Error marshalling item: %v", err)
			failures = append(failures, events.SQSBatchItemFailure{ItemIdentifier: record.MessageId})
		}

		putItemInput := &dynamodb.PutItemInput{
			TableName: aws.String(tableName),
			Item:      av,
		}

		_, err = client.PutItem(ctx, putItemInput)
		if err != nil {
			log.Printf("Error putting item into DynamoDB: %v", err)
			failures = append(failures, events.SQSBatchItemFailure{ItemIdentifier: record.MessageId})
		}
	}

	log.Printf("Number of failures: %v", len(failures))

	return events.SQSEventResponse{BatchItemFailures: failures}, nil
}

func main() {
	lambda.Start(handler)
}
