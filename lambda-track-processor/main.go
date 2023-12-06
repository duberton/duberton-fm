package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log"
	"strings"
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

		client := dynamodb.NewFromConfig(cfg)

		artistAlbumHash := normalizeAndHash(song.Artist, song.Album)
		id := uuid.NewString()

		item := Item{
			Pk:        fmt.Sprintf("%02d", time.Now().Day()),
			Sk:        fmt.Sprintf("%02d-%d#%s", time.Now().Month(), time.Now().Year(), id),
			Artist:    song.Artist,
			Title:     song.Title,
			Album:     song.Album,
			Id:        id,
			Hash:      artistAlbumHash,
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

func normalizeAndHash(str1, str2 string) string {
	normalizedStr1 := normalizeString(str1)
	normalizedStr2 := normalizeString(str2)

	combinedString := normalizedStr1 + normalizedStr2

	hashedValue := sha256.Sum256([]byte(combinedString))

	hashedString := fmt.Sprintf("%x", hashedValue)

	return hashedString
}

func normalizeString(s string) string {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, " ", "")
	return s
}

func main() {
	lambda.Start(handler)
}
