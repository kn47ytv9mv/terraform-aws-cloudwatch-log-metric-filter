resource "random_uuid" "resource" {}

resource "aws_cloudwatch_log_metric_filter" "resource" {
  name           = coalesce(var.name, random_uuid.resource.id)
  log_group_name = var.log_group_name
  pattern        = var.pattern

  apply_on_transformed_logs = var.apply_on_transformed_logs

  metric_transformation {
    name          = var.metric_name
    namespace     = var.metric_namespace
    value         = var.metric_value
    default_value = var.metric_dimensions != null ? null : var.metric_default_value
    unit          = var.metric_unit
    dimensions    = var.metric_dimensions
  }
}

output "id" {
  description = "The ID of the metric filter."
  value       = aws_cloudwatch_log_metric_filter.resource.id
}

output "name" {
  description = "The name of the metric filter, as it identifies the filter within its log group."
  value       = aws_cloudwatch_log_metric_filter.resource.name
}

output "metric_name" {
  description = "The name of the metric the filter publishes. Feed this into terraform-aws-cloudwatch-metric-alarm's metric_name so the alarm and the filter cannot drift apart."
  value       = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).name
}

output "metric_namespace" {
  description = "The namespace the metric is published into. Feed this into terraform-aws-cloudwatch-metric-alarm's namespace."
  value       = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).namespace
}
