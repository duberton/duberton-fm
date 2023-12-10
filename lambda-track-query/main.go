package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/expression"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

const (
	tableName = "duberton-fm"
)

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
	Artist    string `json:"artist"`
	Title     string `json:"title"`
	Album     string `json:"album"`
	Id        string `json:"id"`
	Hash      string `json:"hash"`
	Timestamp string `json:"timestamp"`
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	cfg, _ := config.LoadDefaultConfig(ctx)

	day := request.QueryStringParameters["day"]
	month := request.QueryStringParameters["month"]
	year := request.QueryStringParameters["year"]

	dynamoDBClient := dynamodb.NewFromConfig(cfg)

	filter := expression.KeyAnd(
		expression.Key("pk").Equal(expression.Value(day)),
		expression.Key("sk").BeginsWith(month+"-"+year),
	)

	expr, _ := expression.NewBuilder().WithKeyCondition(filter).Build()

	input := &dynamodb.QueryInput{
		TableName:                 aws.String(tableName),
		KeyConditionExpression:    expr.KeyCondition(),
		FilterExpression:          expr.Filter(),
		ExpressionAttributeNames:  expr.Names(),
		ExpressionAttributeValues: expr.Values(),
	}

	result, err := dynamoDBClient.Query(ctx, input)
	if err != nil {
		log.Printf("Error querying DynamoDB table: %v", err)
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Internal Server Error"}, nil
	}

	var items []Item
	for _, item := range result.Items {
		var newItem Item
		if err := attributevalue.UnmarshalMap(item, &newItem); err != nil {
			log.Printf("Error unmarshalling DynamoDB item: %v", err)
			return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Internal Server Error"}, nil
		}
		items = append(items, newItem)
	}

	responseBody, _ := json.Marshal(convertItems(items))

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       string(responseBody),
		Headers:    map[string]string{"Content-Type": "application/json"},
	}, nil

}

func convertItems(items []Item) []Song {
	var songs []Song

	for _, item := range items {
		songs = append(songs, Song{
			Id:        item.Id,
			Artist:    item.Artist,
			Title:     item.Title,
			Album:     item.Album,
			Hash:      item.Hash,
			Timestamp: item.Timestamp,
		})
	}

	return songs
}

func main() {
	lambda.Start(handler)
}
