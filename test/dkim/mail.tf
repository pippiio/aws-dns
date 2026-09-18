locals {
  rawyaml = yamldecode(file("./dkim_token.yaml"))

  domains = { for domain, zone in local.rawyaml : domain => merge({ email = "disabled" }, zone) }

  enable_strict_dmarc = false

  dmarc = local.enable_strict_dmarc ? "v=DMARC1; p=reject; rua=mailto:%s; adkim=s; aspf=s;" : "v=DMARC1; p=quarantine; rua=mailto:%s;"

  email_provider = {
    disabled = {
      mx_wildcard = false
      mx          = []
      spf         = "v=spf1 ~all"
      dkim        = {}
    }

    custom = {
      mx_wildcard = false
      mx          = []
      spf         = "v=spf1 mx ~all"
      dkim        = {}
    }

    fastmail = {
      mx_wildcard = true
      mx = [
        "10 in1-smtp.messagingengine.com",
        "20 in2-smtp.messagingengine.com",
      ]
      spf = "v=spf1 include:spf.messagingengine.com ~all"
      dkim = {
        "fm1._domainkey" = "fm1.<domain>.dkim.fmhosted.com"
        "fm2._domainkey" = "fm2.<domain>.dkim.fmhosted.com"
        "fm3._domainkey" = "fm3.<domain>.dkim.fmhosted.com"
      }
    }

    protonmail = {
      mx_wildcard = false
      mx = [
        "10 mail.protonmail.ch",
        "20 mailsec.protonmail.ch",
      ]
      spf = "v=spf1 include:_spf.protonmail.ch mx ~all"
      //Same identifier in all three, only the selector differs. Three selectors let Proton rotate keys without DNS changes.
      dkim = {
        "protonmail._domainkey"  = "protonmail.domainkey.<dkim_token>.domains.proton.ch"
        "protonmail2._domainkey" = "protonmail2.domainkey.<dkim_token>.domains.proton.ch"
        "protonmail3._domainkey" = "protonmail3.domainkey.<dkim_token>.domains.proton.ch"
      }
    }

    gmail = {
      mx_wildcard = false
      mx = [
        "1 ASPMX.L.GOOGLE.COM",
        "5 ALT1.ASPMX.L.GOOGLE.COM",
        "5 ALT2.ASPMX.L.GOOGLE.COM",
        "10 ALT3.ASPMX.L.GOOGLE.COM",
        "10 ALT4.ASPMX.L.GOOGLE.COM",
      ]
      spf  = "v=spf1 include:_spf.google.com ~all"
      dkim = {}
    }
  }
}

module "dns" {
  source  = "./../.."
  domains = { for _, domain in local.domains : _ => merge(domain, { records = try(merge(domain.records...), {}) }) }
}
