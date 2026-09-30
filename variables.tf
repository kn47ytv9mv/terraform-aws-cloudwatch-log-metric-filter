variable "name" {
  default     = null
  description = "Name of the metric filter, unique within the log group. If null, a unique name is generated — though a descriptive name is worth setting, since it is what identifies the filter in the console alongside the pattern it applies."
}

variable "log_group_name" {
  default     = null
  description = "Name of the log group whose events are scanned. Take this from terraform-aws-cloudwatch-log-group's name output rather than its arn, since AWS identifies a log group by name here."
}

variable "pattern" {
  default     = null
  description = "Filter pattern deciding which log events count. A bare term such as 'ERROR' matches any event containing it; a space-delimited pattern ('[ip, user, ..., status=4*]') or a JSON pattern ('{ $.eventName = \"ConsoleLogin\" }') names fields that metric_value and metric_dimensions can then reference. An empty string matches every event, which is how a total-throughput metric is built."
}

variable "metric_name" {
  default     = null
  description = "Name of the metric the filter publishes. This is what terraform-aws-cloudwatch-metric-alarm's metric_name must be set to, so choose something an operator will recognize in an alarm notification."
}

variable "metric_namespace" {
  default     = null
  description = "Namespace the metric is published into. Use a namespace of your own rather than an 'AWS/' one, which AWS reserves for its own metrics, and keep related filters together in it so they are browsable as a group."
}

variable "metric_value" {
  default     = "1"
  description = "Value published for each matching event. '1' counts occurrences, which is what most filters want. A field reference publishes a number extracted from the event itself — '$size' over an access log, for example — turning the filter into a measurement rather than a count."
}

variable "metric_default_value" {
  default     = "0"
  description = "Value published for periods in which no event matched. Defaulting this to '0' rather than leaving it unset means an alarm on the metric sits in OK when nothing is wrong instead of INSUFFICIENT_DATA. Ignored when metric_dimensions is set, because AWS rejects the two together."
}

variable "metric_unit" {
  default     = null
  description = "Unit the metric is published in, such as 'Count', 'Bytes', or 'Milliseconds'. An alarm that sets a unit matches no datapoints unless it matches the unit set here, so leaving both unset is the safer pairing."
}

variable "metric_dimensions" {
  default     = null
  description = "Dimensions to publish the metric under, at most three, as a map of dimension name to a reference naming a field the pattern extracts — '$field' for a space-delimited pattern, '$.field' for a JSON one. Literal values are not accepted. Setting this suppresses metric_default_value and multiplies the metric count by the number of distinct field values observed."

  validation {
    condition     = var.metric_dimensions == null || length(var.metric_dimensions) <= 3
    error_message = "A metric filter supports at most three dimensions."
  }

  validation {
    condition     = var.metric_dimensions == null || alltrue([for value in values(var.metric_dimensions) : startswith(value, "$")])
    error_message = "Every dimension value must be a '$field' reference to a field the filter pattern names, not a literal value."
  }
}

variable "apply_on_transformed_logs" {
  default     = null
  description = "Whether the pattern is matched against the transformed form of each event, for a log group that has a transformer configured, rather than the raw event as ingested. If null, AWS matches the raw event."
}
