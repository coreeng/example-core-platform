# Tenants

Tenants are defined in YAML files using a simple schema.

## Schema

The schema is defined in [schema.yaml](schema.yaml) in a format suitable for validation by [Yamale](https://github.com/23andMe/Yamale) and a `Makefile` is provided to perform schema and other validation.

To validate tenants, run `make tenants-validate`.

Please note that if `yq` and `yamale` aren't installed, `docker` images will be used which will affect validation performance.

Example tenant YAML file:

```
name: tenant-example
parent: root
description: "tenant example description"
contactEmail: tenant-example@example.com
costCentre: cost-centre-example
environments:
  - sandbox
  - staging
  - production
```

- The `name` key must contain a unique valid Kubernetes namespace name ([RFC 1123 Label Names](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-label-names))
- The `parent` key may be set to `root`, or another tenant `name`, to indicate a subtenant relationship
- The `description` key must be set to a string describing the tenant
- The `contactEmail` key must be set to a valid email address
- The `costCentre` key must be set to a string identifying the cost centre of the tenant
- The `environments` key must list the environments this tenant should be provisioned in
