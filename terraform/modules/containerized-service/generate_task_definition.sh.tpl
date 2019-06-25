#!/bin/bash

read -r -d '' TASK_DEFINITION <<TASK_DEFINITION_TEXT
{
  "family": "${environment}-${name}",
  "executionRoleArn": "$EXECUTION_ROLE",
  "taskRoleArn": "$TASK_ROLE",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "${cpu}",
  "memory": "${memory}",
  "containerDefinitions": [
    {
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${environment}-${name}",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "container"
        }
      },
      "name": "${environment}-${name}",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG-$COMMIT_HASH",
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": ${container_port},
          "hostPort": ${container_port}
        }
      ],
      "essential": true
    }
  ]
}
TASK_DEFINITION_TEXT

printf "$${TASK_DEFINITION}\n" > task_definition.json
