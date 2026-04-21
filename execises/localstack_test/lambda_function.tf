resource "aws_lambda_function" "greet" {
  function_name    = "localstck_greet"
  role             = aws_iam_role.localstack_lambda_role.arn
  runtime          = "python3.12"
  handler          = "main.lambda_handler"
  filename         = data.archive_file.localstack_greet.output_path
  source_code_hash = data.archive_file.localstack_greet.output_base64sha256

  environment {
    variables = {
      GREET = "Hello"
    }
  }
}
