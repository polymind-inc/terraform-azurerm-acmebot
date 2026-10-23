# Tests

## Unit tests

Unit tests use the native `terraform test` framework with mocked providers. They focus on variable validation and plan-time wiring, and do not require Azure credentials.

Authentication coverage includes Entra-only, custom-OIDC-only, combined providers,
omitted settings, explicit disablement, invalid provider selection and credentials,
and sensitive client secrets that are unknown until apply. Run the suite with
Terraform 1.12 as well as the CI version to check null guards and AVM `for_each`
compatibility at the supported minimum version.

```bash
terraform init -backend=false -test-directory=tests/unit
terraform test -test-directory=tests/unit
```

## End-to-end tests

End-to-end tests are not yet implemented. Use the [`examples/default`](../examples/default) configuration as the deployable smoke-test scenario against a real Azure subscription.
