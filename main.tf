terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "bucket" {
  provider = aws
  bucket   = var.bucket_name

  tags = {
    test = "test"
  }
}

resource "aws_s3_bucket_policy" "allow_lambda_access" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.allow_lambda_access.json
}

data "aws_iam_policy_document" "allow_lambda_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.link-lambda-role.arn]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

data "archive_file" "function_zip" {
  source_dir  = "${path.module}/lambda"
  type        = "zip"
  output_path = var.zipfile
}

resource "aws_lambda_function" "link-lambda" {
  provider      = aws
  function_name = var.lambda_name
  handler       = var.handler
  runtime       = var.runtime
  architectures = [var.architecture]

  filename = var.zipfile
  role     = aws_iam_role.link-lambda-role.arn

  tags = {
    test = "test"
  }
}

resource "aws_iam_role" "link-lambda-role" {
  provider = aws
  name     = "link-lambda-role"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com"]
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

data "aws_iam_policy_document" "lambda-s3-access-policy" {
  statement {
    sid = "allows3getobject"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.bucket.arn
    ]
  }
}

resource "aws_iam_policy" "allow_lambda_access" {
  name   = "AllowLambdaBucketAccess"
  policy = data.aws_iam_policy_document.lambda-s3-access-policy.json
}

resource "aws_iam_role_policy_attachment" "example-attach" {
  role       = aws_iam_role.link-lambda-role.id
  policy_arn = aws_iam_policy.allow_lambda_access.arn
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.bucket.bucket
  key    = "htmltest.html"
  source = "htmltest.html"
  etag = filemd5("htmltest.html")
}

resource "aws_lambda_function_url" "test_live" {
  function_name      = aws_lambda_function.link-lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
