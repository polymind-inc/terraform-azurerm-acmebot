# Tests

## Unit tests

Unit tests use the native `terraform test` framework with mocked providers. They focus on variable validation and plan-time wiring, and do not require Azure credentials.

```bash
terraform init -backend=false
terraform test -test-directory=tests/unit
```

## End-to-end tests

End-to-end tests are not yet implemented. Use the [`examples/default`](../examples/default) configuration as the deployable smoke-test scenario against a real Azure subscription.
