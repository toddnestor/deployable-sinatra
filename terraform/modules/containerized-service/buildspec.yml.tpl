version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region $AWS_REGION)
  build:
    commands:
      - echo Build started on `date`
      - export COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - echo Generate task definition json file
      - |
        cat << 'FILETEXT' >> generate_task_definition.sh
        ${generate_task_definition}
        FILETEXT
      - cat generate_task_definition.sh
      - chmod +x ./generate_task_definition.sh
      - ./generate_task_definition.sh
      - cat task_definition.json
      - echo Register task definition and set new task definition to TASK_DEFINITION variable
      - export TASK_DEFINITION=`aws ecs register-task-definition --cli-input-json "file://task_definition.json" | grep taskDefinitionArn | awk '{ print $2 }' | tr -d ',' | tr -d '"'`
      - echo Generate appspec.yaml
      - |
        cat << 'FILETEXT' >> generate_app_spec.sh
        ${generate_app_spec}
        FILETEXT
      - cat generate_app_spec.sh
      - chmod +x ./generate_app_spec.sh
      - ./generate_app_spec.sh
artifacts:
  files:
    - appspec.yaml
