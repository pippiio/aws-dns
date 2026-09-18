module "dns" {
  source = "./.."
  // Variables can be given as input here to the module
  domains = { for _, domain in local.domains : _ => merge(domain, { records = try(merge(domain.records...), {}) }) }
}

locals {
  domains = yamldecode(file("./test.yml"))
}