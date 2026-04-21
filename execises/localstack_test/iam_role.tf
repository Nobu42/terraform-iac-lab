resource "aws_iam_role" "localstack_lambda_role" {
  name = "loclstack-lambda-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "localstack_lambda_policy" {
  name = "localstack-lambda-policy"
  role = aws_iam_role.localstack_lambda_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : ["dynamodb:*"],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "AllowDynamoDBOperation"
      },
      {
        "Action" : ["s3:*"],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "AllowS3Operation"
      },
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "AllowCWlogsOperation"
      }
    ]
  })
}
