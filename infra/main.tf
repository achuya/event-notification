provider "aws" {
  region = var.aws_region
}

# Lambdaの実行ロール
resource "aws_iam_role" "lambda" {
  name = "event-notification-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# LambdaにCloudWatch Logsの権限を付与
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# LambdaのZIPファイルを作成
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/index.py"
  output_path = "${path.module}/lambda.zip"
}

# Lambda関数
resource "aws_lambda_function" "notification" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "event-notification"
  role             = aws_iam_role.lambda.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = {
    Name = "event-notification"
  }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/event-notification"
  retention_in_days = 7
}

# Step Functionsの実行ロール
resource "aws_iam_role" "sfn" {
  name = "event-notification-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Step FunctionsにLambdaの実行権限を付与
resource "aws_iam_role_policy" "sfn_lambda" {
  name = "event-notification-sfn-lambda-policy"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.notification.arn
        ]
      }
    ]
  })
}

# Step Functions
resource "aws_sfn_state_machine" "notification" {
  name     = "event-notification"
  role_arn = aws_iam_role.sfn.arn

  definition = jsonencode({
    Comment = "ECSデプロイ通知ワークフロー"
    StartAt = "NotifySlack"
    States = {
      NotifySlack = {
        Type     = "Task"
        Resource = aws_lambda_function.notification.arn
        End      = true
      }
    }
  })

  tags = {
    Name = "event-notification"
  }
}

# EventBridgeの実行ロール
resource "aws_iam_role" "eventbridge" {
  name = "event-notification-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# EventBridgeにStep Functionsの実行権限を付与
resource "aws_iam_role_policy" "eventbridge_sfn" {
  name = "event-notification-eventbridge-sfn-policy"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.notification.arn
        ]
      }
    ]
  })
}

# EventBridgeルール（ECSタスクが実行中になったとき）
resource "aws_cloudwatch_event_rule" "ecs_task" {
  name        = "event-notification-ecs-task"
  description = "ECSタスクのステータス変更を検知"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      lastStatus = ["RUNNING"]
    }
  })

  tags = {
    Name = "event-notification-ecs-task"
  }
}

# EventBridgeのターゲット（Step Functions）
resource "aws_cloudwatch_event_target" "sfn" {
  rule     = aws_cloudwatch_event_rule.ecs_task.name
  arn      = aws_sfn_state_machine.notification.arn
  role_arn = aws_iam_role.eventbridge.arn
}