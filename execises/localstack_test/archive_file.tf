data "archive_file" "localstack_greet" {
  type        = "zip"
  source_file = "lambda_sources/localstack_greet/main.py"
  output_path = "upload/localstack_greet.zip"
}
