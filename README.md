# aws-dns

The _aws-dns_ is a generic [Terraform](https://www.terraform.io/) module within the [pippi.io](https://pippi.io) family, maintained by [Tech Chapter](https://techchapter.com/). The pippi.io modules are build to support common use cases often seen at Tech Chapters clients. They are created with best practices in mind and battle tested at scale. All modules are free and open-source under the Mozilla Public License Version 2.0.

The aws-dns module is made to provision and manage [AWS Route53](https://aws.amazon.com/route53/) multiple hosted zones in common scenarious often seen at Tech Chapters clients. This includes, creating dns-records, dns-sec support, https-redirects, and more.

Example usage:
```hcl
provider "aws" {
  region = "us-east-1"
}

module "dns" {
  source = "github.com/pippiio/aws-dns?ref=v1.2.0"

  config      = {
    "example.com" = {
      email = "fastmail"
      records = {
        "@" = {
          type   = "redirect"
          values = ["https://www.example.com"]
        }
        "www" = {
          type   = "cloudfront" # AWS Route53 cloudfront alias
          values = ["xyz123abc.cloudfront.net"]
        }
        "*" = { # Wildcard
          type   = "a"
          values = ["1.2.3.4"]
        }
        "web" = {
          type   = "cname"
          values = ["www.example.com"]
        }
        "$" = { # Apex mx record
          type = "mx"
          ttl  = 3600
          values = [
            "1 ASPMX.L.GOOGLE.COM.",
          ]
        }
        "#" = { # Apex txt record
          type   = "txt"
          ttl    = 3600
          values = ["v=spf1 ~all"]
        }
      }
    }
    "example.co" = {
      disable_dnssec = true                      # DNSSEC not supported for .co tld 
      webredirect    = "https://www.example.com" # HTTPS redirect for example.co & www.example.co using AWS CloudFront
    }
  }
}
```
