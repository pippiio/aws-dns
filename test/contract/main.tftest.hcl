provider "aws" {
  region = "us-east-1"
}

run "email_disabled" {
  variables {
    domains = {
      "pippi.io" = {
        email   = "disabled"
      }
    }
  }

  command = plan

  assert {
    error_message = "No MX record should be created when email provider is set to 'disabled'."
    condition     = length(keys(aws_route53_record.mx)) == 0
  }

  assert {
    error_message = "No Wildcard MX record should be created when email provider is set to 'disabled'."
    condition     = length(keys(aws_route53_record.mx_wildcard)) == 0
  }

  assert {
    error_message = "No DKIM records should be created when email provider is set to 'disabled'."
    condition     = length(aws_route53_record.dkim) == 0
  }

  assert {
    error_message = "SPF record should hard fail when email provider is set to 'disabled'."
    condition     = contains(aws_route53_record.txt["pippi.io/#"].records, "v=spf1 -all")
  }

  assert {
    error_message = "DMARC record should be created when email provider is set to 'disabled'."
    condition     = contains(keys(aws_route53_record.dmarc), "pippi.io")
  }
}

run "email_fastmail" {
  variables {
    domains = {
      "pippi.io" = {
        email   = "fastmail"
      }
    }
  }

  command = plan

  assert {
    error_message = "MX record should be created when email provider is set to 'fastmail'."
    condition     = can(one(keys(aws_route53_record.mx)))
  }

  assert {
    error_message = "Wildcard MX record should be created when email provider is set to 'fastmail'."
    condition     = can(one(keys(aws_route53_record.mx_wildcard)))
  }

  assert {
    error_message = "Multiple DKIM cname records should be created when email provider is set to 'fastmail'."
    condition     = length(aws_route53_record.dkim) == 3
  }

  assert {
    error_message = "SPF record should include fastmail servers when email provider is set to 'fastmail'."
    condition     = contains(aws_route53_record.txt["pippi.io/#"].records, "v=spf1 include:spf.messagingengine.com ~all")
  }

  assert {
    error_message = "DMARC record should be created when email provider is set to 'fastmail'."
    condition     = contains(keys(aws_route53_record.dmarc), "pippi.io")
  }
}

run "email_gmail" {
  variables {
    domains = {
      "pippi.io" = {
        email   = "gmail"
        dkim = {
          "google" = {
            p = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
          }
        }
      }
    }
  }

  command = plan

  assert {
    error_message = "MX record should be created when email provider is set to 'gmail'."
    condition     = can(one(keys(aws_route53_record.mx)))
  }

  assert {
    error_message = "No Wildcard MX record should be created when email provider is set to 'gmail'."
    condition     = length(keys(aws_route53_record.mx_wildcard)) == 0
  }

  assert {
    error_message = "DKIM record should be created when email provider is set to 'gmail'."
    condition     = length(aws_route53_record.dkim) == 1
  }

  assert {
    error_message = "DKIM record should be TXT type when email provider is set to 'gmail'."
    condition     = aws_route53_record.dkim["pippi.io/google"].type == "TXT"
  }

  assert {
    error_message = "DKIM TXT record should be explicit value when email provider is set to 'gmail'."
    condition     = one(aws_route53_record.dkim["pippi.io/google"].records) == "v=DKIM1; k=rsa; p=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
  }

  assert {
    error_message = "SPF record should include gmail servers when email provider is set to 'gmail'."
    condition     = contains(aws_route53_record.txt["pippi.io/#"].records, "v=spf1 include:_spf.google.com ~all")
  }

  assert {
    error_message = "DMARC record should be created when email provider is set to 'gmail'."
    condition     = contains(keys(aws_route53_record.dmarc), "pippi.io")
  }
}

run "protonmail" {
  variables {
    domains = {
      "pippi.io" = {
        email   = "protonmail"
        dkim = {
          "protonmail" = {
            cname = "protonmail.domainkey.abc123xyz.domains.proton.ch."
          }
          "protonmail2" = {
            cname = "protonmail.domainkey.abc456xyx.domains.proton.ch."
          }
          "protonmail3" = {
            cname = "protonmail.domainkey.abc789xyx.domains.proton.ch."
          }
        }
      }
    }
  }

  command = plan

  assert {
    error_message = "MX record should be created when email provider is set to 'protonmail'."
    condition     = length(aws_route53_record.mx["pippi.io"].records) == 2
  }

  assert {
    error_message = "No Wildcard MX record should be created when email provider is set to 'protonmail'."
    condition     = length(keys(aws_route53_record.mx_wildcard)) == 0
  }

  assert {
    error_message = "DMARC record should be created when email provider is set to 'protonmail'."
    condition     = contains(keys(aws_route53_record.dmarc), "pippi.io")
  }

  assert {
    error_message = "Three DKIM records should be created when email provider is set to 'protonmail'."
    condition     = length(aws_route53_record.dkim) == 3
  }

  assert {
    error_message = "DKIM records should be CNAME type when email provider is set to 'protonmail'."
    condition     = aws_route53_record.dkim["pippi.io/protonmail"].type == "CNAME"
  }

  assert {
    error_message = "DKIM CNAME record should point to the provided proton value when email provider is set to 'protonmail'."
    condition     = one(aws_route53_record.dkim["pippi.io/protonmail"].records) == "protonmail.domainkey.abc123xyz.domains.proton.ch."
  }

  assert {
    error_message = "SPF record should include protonmail servers when email provider is set to 'protonmail'."
    condition     = contains(aws_route53_record.txt["pippi.io/#"].records, "v=spf1 include:_spf.protonmail.ch mx ~all")
  }
}
