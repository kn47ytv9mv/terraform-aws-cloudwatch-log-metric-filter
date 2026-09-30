mock_provider "aws" {}

run "more_than_three_dimensions_are_rejected" {
  command = plan

  variables {
    log_group_name   = "/aws/cloudtrail/example"
    pattern          = "[account, region, service, resource]"
    metric_name      = "Events"
    metric_namespace = "Example"
    metric_dimensions = {
      Account  = "$account"
      Region   = "$region"
      Service  = "$service"
      Resource = "$resource"
    }
  }

  expect_failures = [var.metric_dimensions]
}

run "literal_dimension_values_are_rejected" {
  command = plan

  variables {
    log_group_name    = "/aws/cloudtrail/example"
    pattern           = "[account, region]"
    metric_name       = "Events"
    metric_namespace  = "Example"
    metric_dimensions = { Region = "us-east-1" }
  }

  expect_failures = [var.metric_dimensions]
}

run "name_defaults_to_random_uuid" {
  command = apply

  variables {
    log_group_name   = "/aws/cloudtrail/example"
    pattern          = "{ $.errorCode = \"AccessDenied\" }"
    metric_name      = "UnauthorizedApiCalls"
    metric_namespace = "Example"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.resource.name == random_uuid.resource.id
    error_message = "Leaving name unset should fall back to the generated random_uuid."
  }
}

run "defaults_count_occurrences_and_publish_zero_when_idle" {
  command = plan

  variables {
    log_group_name   = "/aws/cloudtrail/example"
    pattern          = "{ $.errorCode = \"AccessDenied\" }"
    metric_name      = "UnauthorizedApiCalls"
    metric_namespace = "Example"
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).value == "1"
    error_message = "The metric value should default to counting one per matching event."
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).default_value == "0"
    error_message = "A period with no match should publish zero, so an alarm on the metric reports OK rather than INSUFFICIENT_DATA."
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).unit == null
    error_message = "Leaving metric_unit unset should publish no unit, which matches an alarm that sets none."
  }
}

run "dimensions_suppress_the_default_value" {
  command = plan

  variables {
    log_group_name       = "/aws/cloudtrail/example"
    pattern              = "{ $.errorCode = \"AccessDenied\" }"
    metric_name          = "UnauthorizedApiCalls"
    metric_namespace     = "Example"
    metric_default_value = "0"
    metric_dimensions    = { EventSource = "$.eventSource" }
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).default_value == null
    error_message = "AWS rejects a default_value alongside dimensions, so the module must drop it rather than pass both."
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).dimensions["EventSource"] == "$.eventSource"
    error_message = "Dimensions should pass through unchanged."
  }
}

run "extracted_values_and_units_pass_through" {
  command = plan

  variables {
    log_group_name   = "/aws/alb/example"
    pattern          = "[..., sent_bytes, request, rest]"
    metric_name      = "BytesSent"
    metric_namespace = "Example"
    metric_value     = "$sent_bytes"
    metric_unit      = "Bytes"
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).value == "$sent_bytes"
    error_message = "A '$field' metric value should pass through so the filter measures rather than counts."
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).unit == "Bytes"
    error_message = "metric_unit should pass through to the metric transformation."
  }
}

run "readme_authentication_failures_example" {
  command = plan

  variables {
    name             = "authentication-failures"
    log_group_name   = "/aws/cloudtrail/example"
    pattern          = "{ ($.eventName = \"ConsoleLogin\") && ($.errorMessage = \"Failed authentication\") }"
    metric_name      = "AuthenticationFailures"
    metric_namespace = "Example/Security"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.resource.name == "authentication-failures"
    error_message = "An explicit name should override the random_uuid fallback."
  }
}

run "readme_response_time_example" {
  command = plan

  variables {
    name             = "slow-requests"
    log_group_name   = "/aws/apigateway/example"
    pattern          = "[timestamp, request_id, status_code, response_time]"
    metric_name      = "ResponseTime"
    metric_namespace = "Example/Api"
    metric_value     = "$response_time"
    metric_unit      = "Milliseconds"

    metric_dimensions = { StatusCode = "$status_code" }
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.resource.metric_transformation).dimensions["StatusCode"] == "$status_code"
    error_message = "The dimensioned example should publish the metric per status code."
  }
}
