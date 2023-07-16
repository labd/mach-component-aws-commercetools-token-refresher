# Commercetools token refresher for AWS

Refresh Commercetools access token secrets by asking for a new token. 10 minutes after initial token request the Commercetools API returns a new token.
They both still work until their expiry date.

This component is for AWS, there is also a [GCP version](https://github.com/mach-composer/mach-component-gcp-commercetools-token-refresher)

## Usage


Use the following attributes to configure this component in MACH:

```yaml
sites:
  - identifier: some site
    components:
    - name: ct-refresher
...

components:
- name: ct-refresher
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

  # Optional; KMS key to use for the secret
  kms_key_id = "<your-kms-key-id>"
}
```

In your lambda function you can pass the reference to the secretsmanager value as
```
CT_ACCESS_TOKEN_SECRET_NAME = module.ct_secret.name
```

### Running in VPC

By providing VPC information through the variables, the rotator lambda can be run within the VPC;

```yaml
sites:
  - identifier: some site
    components:
    - name: ct-refresher
      variables:
        vpc:
          id: <your-vpc-id>
          subnet_ids: <your-subnet-ids>
          ingress_subnet: <your-ingress-subnet>
```


### Adding KMS keys

KMS keys can be provided through the `kms_keys` object;


```yaml
sites:
  - identifier: some site
    components:
    - name: ct-refresher
      variables:
        kms_keys:
          cloudwatch: <cloudwatch-kms-key>
          lambda: <lambda-kms-key>
          secretmanager: <secretmanager-kms-key>
```
