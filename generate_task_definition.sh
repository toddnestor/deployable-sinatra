#!/bin/bash



read -r -d '' TASK_DEFINITION <<TEST
{
  "family": "development-sinatra",
  "executionRoleArn": "$EXECUTION_ROLE",
  "taskRoleArn": "$TASK_ROLE",
  "networkMode": "awsvpc",
  "containerDefinitions": [
    {
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "development-sinatra",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "container"
        }
      },
      "name": "development-sinatra",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION",
      "cpu": 0,
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": 4000,
          "hostPort": 4000
        }
      ],
      "memory": 512,
      "essential": true
    }
  ]
}
TEST

printf "${TASK_DEFINITION}\n" > task_definition.json
