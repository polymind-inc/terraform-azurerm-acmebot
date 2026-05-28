# Tests

## Unit tests

Variable validation tests using the native `terraform test` framework. These do not require Azure credentials and run as plan-only validation checks.

```bash
terraform init -backend=false
terraform test -test-directory=tests/unit
```

## End-to-end tests

End-to-end tests are not yet implemented. The intended pattern is to use the [`examples/default`](../examples/default) configuration as a deployable scenario against a real Azure subscription.
