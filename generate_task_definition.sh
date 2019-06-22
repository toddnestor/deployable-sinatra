#!/bin/bash

read -r -d '' TASK_DEFINITION <<TEST
{
  "family": "development-sinatra",
  "executionRoleArn": "$EXECUTION_ROLE",
  "taskRoleArn": "$TASK_ROLE",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "development-sinatra",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "container"
        }
      },
      "name": "development-sinatra",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION",
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": 4000,
          "hostPort": 4000
        }
      ],
      "essential": true
    }
  ]
}
TEST

printf "${TASK_DEFINITION}\n" > task_definition.json

cat task_definition.json
