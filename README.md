# Commercetools token refresher component

Refresh Commercetools access token secrets by asking for a new token. 10 minutes after initial token request the Commercetools API returns a new token.
They both still work until their expiry date.

## Usage


Use the following attributes to configure this component in MACH:

```yaml
sites:
  - identifier: some site
    components:
    - name: rotator
...

components:
- name: rotator
  source: git::https://github.com/labd/mach-component-aws-commercetools-token-refresher.git//terraform
  version: <git hash of version you want to release>
  integrations: ["aws", "commercetools", "sentry"]
```

Other components must configure their commercetools secrets with a reference to this refresher.

```terraform
locals {
  ct_scopes = formatlist("%s:%s", [
    "manage_orders",
    "view_orders",
    "manage_payments",
    "view_payments"
  ], var.ct_project_key)
}

module "ct_secret" {
  source = "git::https://github.com/labd/mach-component-aws-commercetools-token-refresher.git//terraform/secret"

  name   = "<your-component-name>"
  site   = var.site
  scopes = local.ct_scopes
}
```

In your lambda function you can pass the reference to the secretsmanager value as
```
CT_ACCESS_TOKEN_SECRET_NAME = module.ct_secret.name
```