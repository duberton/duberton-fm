package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/google/uuid"
)

const (
	tableName = "duberton-fm"
)

// Item represents the data structure to be stored in DynamoDB.
type Item struct {
	Pk        string `dynamodbav:"pk"`
	Sk        string `dynamodbav:"sk"`
	Artist    string `dynamodbav:"artist"`
	Title     string `dynamodbav:"title"`
	Album     string `dynamodbav:"album"`
	Id        string `dynamodbav:"id"`
	Hash      string `dynamodbav:"hash"`
	Timestamp string `dynamodbav:"timestamp"`
}

type Song struct {
	Artist string `json:"artist"`
	Title  string `json:"title"`
	Album  string `json:"album"`
	Hash   string `json:"hash"`
}

func handler(ctx context.Context, event events.SQSEvent) (events.SQSEventResponse, error) {
	failures := []events.SQSBatchItemFailure{}

	cfg, _ := config.LoadDefaultConfig(ctx)

	var song Song

	for _, record := range event.Records {
		if err := json.Unmarshal([]byte(record.Body), &song); err != nil {
			failures = append(failures, events.SQSBatchItemFailure{ItemIdentifier: record.MessageId})
		}

		log.Printf("Record with the following body %s and message id %s", record.Body, record.MessageId)

		dynamoDBClient := dynamodb.NewFromConfig(cfg)

		id := uuid.NewString()

		item := Item{
			Pk:        fmt.Sprintf("%02d", time.Now().Day()),
			Sk:        fmt.Sprintf("%02d-%d#%s", time.Now().Month(), time.Now().Year(), id),
			Artist:    song.Artist,
			Title:     song.Title,
			Album:     song.Album,
			Id:        id,
			Hash:      song.Hash,
			Timestamp: time.Now().Format(time.RFC3339),
		}

		av, err := attributevalue.MarshalMap(item)

		log.Printf("DynamoDB attribute value: %v", av)

		if err != nil {
			log.Printf("Error marshalling item: %v", err)
			failures = append(failures, events.SQSBatchItemFailure{ItemIdentifier: record.MessageId})
		}

		putItemInput := &dynamodb.PutItemInput{
			TableName: aws.String(tableName),
			Item:      av,
		}

		_, err = dynamoDBClient.PutItem(ctx, putItemInput)
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
