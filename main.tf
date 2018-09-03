variable "slack_webhook_url" {}

variable "prefix" {}

variable "pipeline" {
  default = ""
}

variable "state" {
  default = <<STATE
["STARTED", "SUCCEEDED", "FAILED"]
STATE
}

locals {
  pipeline_json = "${var.pipeline == "" ? "" : "\"pipeline\": ${var.pipeline},"}"
}

resource "aws_cloudwatch_event_rule" "main" {
  name = "${var.prefix}-codepipelineNotifications"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codepipeline"
  ],
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "detail": {
    ${local.pipeline_json}
    "state": ${var.state}
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "main" {
  rule      = "${aws_cloudwatch_event_rule.main.name}"
  target_id = "SendToSNS"
  arn       = "${aws_sns_topic.main.arn}"
}

resource "aws_sns_topic" "main" {
  name         = "${var.prefix}-codepipelineNotifications"
  display_name = "CodePipeline notifications"
}

resource "aws_sns_topic_policy" "main" {
  arn = "${aws_sns_topic.main.arn}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "AWSEvents_smebiz-codepipeline-events_SendToSNS",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sns:Publish",
      "Resource": "${aws_sns_topic.main.arn}"
    }
  ]
}

EOF
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.prefix}-codepipelineNotificationsLambda"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.json}"
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.prefix}-codepipelineNotifications"
  role   = "${aws_iam_role.lambda.id}"
  policy = "${data.aws_iam_policy_document.lambda_permissions.json}"
}

resource "aws_lambda_function" "main" {
  handler          = "index.handler"
  runtime          = "nodejs8.10"
  function_name    = "${var.prefix}-codepipelineNotifications"
  filename         = "${path.module}/functions/notifications/dist.zip"
  role             = "${aws_iam_role.lambda.arn}"
  source_code_hash = "${base64sha256(file("${path.module}/functions/notifications/dist.zip"))}"

  environment {
    variables = {
      SLACK_WEBHOOK_URL = "${var.slack_webhook_url}"
    }
  }
}

resource "aws_lambda_permission" "main" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  function_name = "${aws_lambda_function.main.function_name}"
  source_arn    = "${aws_sns_topic.main.arn}"
}

resource "aws_sns_topic_subscription" "main" {
  topic_arn = "${aws_sns_topic.main.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.main.arn}"
}
