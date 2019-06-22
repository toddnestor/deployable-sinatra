#!/bin/bash

read -r -d '' APP_SPEC <<APP_SPEC_TEXT
version: %s
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "%s"
        LoadBalancerInfo:
          ContainerName: "development-sinatra"
          ContainerPort: "4000"
        PlatformVersion: "LATEST"
APP_SPEC_TEXT

printf "${APP_SPEC}\n" $IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION $TASK_DEFINITION > appspec.yaml
