# Bootstrap

Creates one S3 state bucket per environment. Run once, before any environment is
initialized against its backend.

Each environment gets its own bucket rather than a shared bucket with separate keys, so
the trust boundary is the bucket: prod state access is granted independently of dev, and a
mistake in one environment cannot reach the other's state.

Buckets are versioned, encrypted with SSE-S3 (bucket keys enabled), blocked from all
public access, owner-enforced, deny non-TLS requests, and expire noncurrent state versions
after 90 days. They are marked `prevent_destroy`.

State locking in the environments uses S3 native conditional writes
(`use_lockfile = true`), so no DynamoDB table is needed.

## Local state

This root module keeps local state, because it creates the buckets every other root module
stores its state in. `terraform.tfstate` here is gitignored. The resources are plain S3
buckets, so a lost state file is recoverable with `terraform import`.

## Usage

```sh
terraform init
terraform apply
terraform output state_bucket_names
```

Bucket names are `<state_bucket_prefix>-<environment>-<account_id>`, giving
`bla-demo-tfstate-dev-<account_id>` and `bla-demo-tfstate-prod-<account_id>`. The account
ID is read from the caller identity.

Backend blocks cannot use variables, so these names are written literally in
`environments/Dev/backend.tf` and `environments/Prod/backend.tf`. After applying, confirm
the `state_bucket_names` output matches those two files, then initialize each environment
with `terraform init -reconfigure`.
