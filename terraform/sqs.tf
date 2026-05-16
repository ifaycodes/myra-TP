resource "aws_sqs_queue" "ingest" {
  name                       = "queue-ingest"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = {
    Project     = "Myra Fintech"
    Environment = "development"
  }
}

resource "aws_sqs_queue" "validated" {
  name                       = "queue-validated"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30

  tags = {
    Project     = "Myra Fintech"
    Environment = "development"
  }
}

output "ingest_queue_url" {
  value = aws_sqs_queue.ingest.url
}

output "validated_queue_url" {
  value = aws_sqs_queue.validated.url
}