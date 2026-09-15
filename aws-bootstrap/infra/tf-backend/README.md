# AWS Bootstrap - Terraform Remote Backend

S3 backend bootstrap utility built-in with a clean separation of statefiles across projects and for modules within the same project.

## Terminology

| Term    | Meaning                                                                                           |
| ------- | ------------------------------------------------------------------------------------------------- |
| Account | AWS account that owns the backend. The bucket name is prefixed with the account ID.               |
| Project | Boundary for one backend bucket: `{account_id}-{project}-tf-backend`.                             |
| Module  | Service deployed together (for example `frontend` or `backend`). State key is `modules/{module}`. |

One bucket per project. One state file per module. Re-run the script for each new module; the bucket is reused if it already exists.

## Usage

### 1. Bootstrap the backend

Requires AWS CLI, Terraform `~> 1.14`, and credentials that can create S3.

```shell
cd aws-bootstrap/infra/tf-backend
./bootstrap.sh my-app frontend eu-west-1
```

Arguments: `project`, `module`, and optional `region` (default `eu-west-1`).

### 2. Copy the config into the target project

The script writes `.out/config.tfbackend`. Copy it next to an empty S3 backend block, for example `environments/dev/config.tfbackend`, and commit that file.

```hcl
terraform {
  backend "s3" {}
}
```

### 3. Initialize the backend

```shell
terraform init -backend-config="./environments/dev/config.tfbackend"
```

## FAQ

#### What does this module create ?

- S3 bucket `{account_id}-{project}-tf-backend` with versioning, AES256
  encryption, public access blocked, and `force_destroy = false`
- Native S3 lockfile (`use_lockfile = true`); no DynamoDB table
- Backend config at `.out/config.tfbackend` with key `modules/{module}`

If that infrastructure already exists, i.e. you are working on a new module in a
pre-configured deployment environment, then no additional resources are
provisioned and just the `config.tfbackend` file is returned.

#### Can I split my resources across multiple terraform backends ?

This module is intentionally opinionated to standardize how we manage infra.
One bucket per project, one state file per module. Adhere to that definition
as much as possible.

#### Why is bootstrap infrastructure state not kept in version control ?

Bootstrap Terraform state is discarded after apply. Recreate is driven by
whether the bucket already exists, not by saved state. The bucket itself is
the source of truth: versioning and `force_destroy = false` protect it from
accidental deletion.
