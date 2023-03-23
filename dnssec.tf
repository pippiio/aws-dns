data "aws_iam_policy_document" "dnssec" {
  policy_id = "dnssec-policy"

  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "Allow Route 53 DNSSEC Service"
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
    ]

    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:route53:::hostedzone/*"]
    }
  }


  statement {
    sid       = "Allow Route 53 DNSSEC to CreateGrant"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:CreateGrant"]

    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = [true]
    }
  }
}

resource "aws_kms_key" "dnssec" {
  description              = "KMS CMK used for Route53 DNSSEC signing"
  enable_key_rotation      = false
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  policy                   = data.aws_iam_policy_document.dnssec.json

  tags = merge(local.default_tags, {
    "Name" = "${local.name_prefix}dnssec-kms"
  })
}

resource "aws_kms_alias" "dnssec" {
  name          = "alias/${local.name_prefix}dnssec-kms-cmk"
  target_key_id = aws_kms_key.dnssec.key_id
}

resource "aws_route53_key_signing_key" "dnssec" {
  for_each = { for domain, zone in var.domains : domain => zone if zone.disable_dnssec == false }

  hosted_zone_id             = aws_route53_zone.this[each.key].id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = replace(title(replace(each.key, "/[^a-zA-Z0-9]/", " ")), " ", "")
}

resource "aws_route53_hosted_zone_dnssec" "dnssec" {
  for_each = { for domain, zone in var.domains : domain => zone if zone.disable_dnssec == false }

  hosted_zone_id = aws_route53_key_signing_key.dnssec[each.key].hosted_zone_id

  depends_on = [aws_route53_key_signing_key.dnssec]
}
