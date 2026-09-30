# terraform-aws-cloudwatch-log-metric-filter

Terraform module for a CloudWatch Logs metric filter — a pattern over
log text that publishes a CloudWatch metric, so an alarm can fire on
what the logs actually say rather than only on what a resource reports
about itself.

## Cost

The filter itself is free: CloudWatch Logs charges nothing for scanning
events it has already ingested. The metric it publishes is a custom
metric, and custom metrics bill per metric per month. A filter with no
dimensions publishes exactly one; a filter with dimensions publishes
one per distinct combination of observed field values, which is how a
single filter over a high-cardinality field turns into a large bill.
Any alarm placed on the metric bills separately as an alarm. See AWS's
[CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) page
for current rates.

## Design

A metric filter is half of a control: it converts log text into a
number, and an alarm converts that number into a notification. Pair
this module with
[`terraform-aws-cloudwatch-metric-alarm`](https://github.com/kn47ytv9mv/terraform-aws-cloudwatch-metric-alarm),
whose `namespace` and `metric_name` come from this module's outputs so
the two cannot drift apart. A filter with no alarm on it publishes a
metric nobody reads.

The module manages one filter per call rather than accepting a map of
them. Instances are not interchangeable: a filter that sets
`metric_dimensions` is structurally a different thing from one that
sets `metric_default_value`, since AWS accepts only one of the two, and
a map would push that constraint into a whole-collection validation
that cannot name the offending entry. More importantly, every filter
exists to be alarmed on, and an alarm needs that one filter's metric
name and namespace — a map-shaped output forces a keyed lookup at every
alarm call site. A caller who genuinely wants several filters over one
log group applies `for_each` to this module and to the alarm module
with the same local map, which keeps the pairing visible.

### Publishing zero when nothing matches

CloudWatch publishes a datapoint for a metric filter only in periods
where the pattern actually matched something. That is rarely what an
operator wants: an alarm on "authentication failures" then sits in
`INSUFFICIENT_DATA` for as long as nothing is wrong, which is
indistinguishable at a glance from an alarm that is broken. Setting
`default_value` makes "no matches" a real datapoint of its own, so the
alarm reports OK during quiet periods and the metric graph shows a
continuous line instead of isolated spikes.

This module therefore defaults `metric_default_value` to `0`, which
deviates from AWS's own behavior of publishing nothing. The cost of the
deviation is one datapoint per period whether or not anything happened,
where AWS would have published none; that is the right trade-off for a
metric whose purpose is to be alarmed on. A caller who wants AWS's
behavior — for a metric charted rather than alarmed, or one where a gap
is meaningful — sets `metric_default_value = null`.

### What the filter pattern has to name

`metric_value` and `metric_dimensions` are not free-form. A value of
`"1"` counts matching events and needs nothing from the pattern, but a
value like `"$sent_bytes"` publishes a number lifted out of the event,
and that field only exists if the pattern named it — a space-delimited
pattern such as `[timestamp, request_id, status_code, sent_bytes]`, or a
JSON pattern whose fields are addressed as `$.sent_bytes`. The same
holds for every dimension value, which must be a field reference and
never a literal string; AWS provides no way to stamp a constant
dimension onto the metric.

Two hard limits follow. A filter carries at most three dimensions, and
this module rejects both a fourth and a literal dimension value at plan
time rather than letting AWS reject them mid-apply. A filter with
dimensions also cannot carry a `default_value` at all, because AWS has
no field value to attach the zero to when nothing matched. Since
`metric_default_value` defaults to `0`, failing on that combination
would mean rejecting a configuration the caller never wrote, so the
module drops the default value whenever `metric_dimensions` is set. A
dimensioned metric therefore keeps AWS's gap-on-no-match behavior, and
its alarm wants `treat_missing_data = "notBreaching"` to compensate.

The log group itself is out of scope; create it with
[`terraform-aws-cloudwatch-log-group`](https://github.com/kn47ytv9mv/terraform-aws-cloudwatch-log-group)
and pass its `name` output in.

## Usage

```hcl
module "authentication_failures" {
  source = "kn47ytv9mv/cloudwatch-log-metric-filter/aws"

  name           = "authentication-failures"
  log_group_name = module.trail_logs.name

  pattern = "{ ($.eventName = \"ConsoleLogin\") && ($.errorMessage = \"Failed authentication\") }"

  metric_name      = "AuthenticationFailures"
  metric_namespace = "Example/Security"
}

module "authentication_failures_alarm" {
  source = "kn47ytv9mv/cloudwatch-metric-alarm/aws"

  alarm_name        = "authentication-failures-high"
  alarm_description = "More than 20 console sign-in failures in five minutes. Check CloudTrail for the source addresses."

  namespace   = module.authentication_failures.metric_namespace
  metric_name = module.authentication_failures.metric_name

  statistic          = "Sum"
  period             = 300
  evaluation_periods = 1

  comparison_operator = "GreaterThanThreshold"
  threshold           = 20

  alarm_actions = [module.alerts.arn]
  ok_actions    = [module.alerts.arn]
}
```

Or directly from this repository, measuring a number carried in the log
line rather than counting events, broken out per status code:

```hcl
module "response_time" {
  source = "github.com/kn47ytv9mv/terraform-aws-cloudwatch-log-metric-filter"

  name           = "slow-requests"
  log_group_name = module.api_logs.name

  pattern = "[timestamp, request_id, status_code, response_time]"

  metric_name      = "ResponseTime"
  metric_namespace = "Example/Api"
  metric_value     = "$response_time"
  metric_unit      = "Milliseconds"

  metric_dimensions = { StatusCode = "$status_code" }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.0 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the metric filter, unique within the log group. If null, a unique name is generated. | `null` | no |
| log_group_name | Name of the log group whose events are scanned. Take this from terraform-aws-cloudwatch-log-group's `name` output, since AWS identifies a log group by name here. | `null` | no |
| pattern | Filter pattern deciding which log events count. Fields it names are what `metric_value` and `metric_dimensions` may reference. An empty string matches every event. | `null` | no |
| metric_name | Name of the metric the filter publishes, and what terraform-aws-cloudwatch-metric-alarm's `metric_name` must be set to. | `null` | no |
| metric_namespace | Namespace the metric is published into. Use one of your own; AWS reserves the `AWS/` namespaces for its own metrics. | `null` | no |
| metric_value | Value published for each matching event. `'1'` counts occurrences; a field reference publishes a number extracted from the event. | `"1"` | no |
| metric_default_value | Value published for periods in which no event matched. Ignored when `metric_dimensions` is set. | `"0"` | no |
| metric_unit | Unit the metric is published in, such as `'Count'`, `'Bytes'`, or `'Milliseconds'`. | `null` | no |
| metric_dimensions | Dimensions to publish the metric under, at most three, each value a field reference rather than a literal. Suppresses `metric_default_value`. | `null` | no |
| apply_on_transformed_logs | Whether the pattern is matched against the transformed form of each event rather than the raw event as ingested. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the metric filter. |
| name | The name of the metric filter, as it identifies the filter within its log group. |
| metric_name | The name of the metric the filter publishes. Feed this into terraform-aws-cloudwatch-metric-alarm's `metric_name` so the alarm and the filter cannot drift apart. |
| metric_namespace | The namespace the metric is published into. Feed this into terraform-aws-cloudwatch-metric-alarm's `namespace`. |

## License

MIT — see [LICENSE.md](LICENSE.md).
