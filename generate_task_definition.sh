#!/bin/bash



read -r -d '' TASK_DEFINITION <<TEST
{
  "family": "development-sinatra",
  "containerDefinitions": [
    {
      "name": "development-sinatra",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION",
      "cpu": 100,
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": 4000,
          "hostPort": 4000
        }
      ],
      "memory": 128,
      "essential": true
    }
  ]
}
TEST

printf "${TASK_DEFINITION}\n" > task_definition.json
