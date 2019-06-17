#!/bin/bash

printf 'version: %s\nResources:\n  -TargetService:\n    Type: AWS::ECS::Service\n    Properties:\n    TaskDefinition: "arn:aws:ecs:us-east-2:591328757508:task-definition/development-sinatra:22"\n' $IMAGE_TAG-$CODEBUILD_RESOLVED_SOURCE_VERSION > appspec.yml
