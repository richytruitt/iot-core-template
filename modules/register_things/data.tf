data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "scoped" {
  for_each = local.devices_by_name
  statement {
    effect = "Allow"
    actions = [
      "iot:Connect"
    ]
    resources = [
      "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/${each.value.name}"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "iot:Publish"
    ]
    resources = [
      "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/devices/${each.value.name}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "iot:Subscribe"
    ]
    resources = [
      "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/devices/${each.value.name}/*"
    ]
  }
  statement {
    effect = "Allow"

    actions = [
      "iot:Receive"
    ]
    resources = [
      "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/devices/${each.value.name}/*"
    ]
  }
}