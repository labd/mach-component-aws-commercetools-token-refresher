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
  integrations: ["aws", "commercetools"]