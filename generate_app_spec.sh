#!/bin/bash



read -r -d '' APP_SPEC <<APP_SPEC_TEXT
version: %s
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "arn:aws:ecs:us-east-2:591328757508:task-definition/development-sinatra:34"
        LoadBalancerInfo:
          ContainerName: "development-sinatra"
          ContainerPort: "4000"
        PlatformVersion: "LATEST"
APP_SPEC_TEXT

printf "${APP_SPEC}\n" $IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION $IMAGE_TAG > appspec.yaml
