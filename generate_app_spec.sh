#!/bin/bash

read -r -d '' APP_SPEC <<TEST
version: %s
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "arn:aws:ecs:us-east-2:591328757508:task-definition/development-sinatra:26"
        LoadBalancerInfo:
          ContainerName: "%s"
          ContainerPort: "4000"
        PlatformVersion: "LATEST"
TEST

printf "${APP_SPEC}\n" $IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION $IMAGE_TAG > appspec.yml
