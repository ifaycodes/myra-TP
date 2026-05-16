resource "aws_cloudwatch_metric_alarm" "queue_backup" {
  alarm_name          = "queue-backup"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Queue is backing up"

  dimensions = {
    QueueName = aws_sqs_queue.ingest.name
  }
}

resource "aws_cloudwatch_metric_alarm" "processing_errors" {
  alarm_name          = "processing-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedInvocations"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Processing stage is throwing errors"
}