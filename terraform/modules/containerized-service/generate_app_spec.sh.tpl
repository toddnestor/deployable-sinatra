#!/bin/bash

read -r -d '' APP_SPEC <<APP_SPEC_TEXT
version: %s
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "%s"
        LoadBalancerInfo:
          ContainerName: "${environment}-${name}"
          ContainerPort: "${container_port}"
        PlatformVersion: "LATEST"
APP_SPEC_TEXT

printf "$${APP_SPEC}\n" $IMAGE_TAG-$COMMIT_HASH $TASK_DEFINITION > appspec.yaml
