# Terraform Remote Backend Bootstrap Module

Bootstraps a Terraform Remote Backend for a service module.
A service module refers to one or more resources that should be managed and deployed together, e.g. Frontend, Backend.

## Usage

#### 1. Provision infrastructure for Terraform Remote Backend

```bash
$ sh bootstrap.sh
```

The script produces:
- A terraform backend configuration file you can copy/paste to your target project to load the correct Terraform backend.

#### 2. Commit backend.tf to version control

Typically it's a good idea to commit the `backend.tf` together with the respective `terraform.tfvars` to your project's repository to store a complete deployment environment configuration that everyone in your team can use.

#### 3. Init Backend on your repository

After adding the configuration file to your repository, you can initialize the backend using

```hcl
$ terraform init -backend-config="./environments/dev/config.tfbackend"
```

## FAQ

#### What does this module create ?

This module transparently handles the process of creating the necessary infrastructure to store terraform state files remotely and outputs the Terraform Backend Configuration file (backend.tf) you should use to deploy your infrastructure.

If that infrastructure already exists, i.e. you are working on a new module in a pre-configured deployment environment, then no additional resources are provisioned and just the backend.tf file is returned.

#### Can I split my resources across multiple terraform backends ?

We have made this module intentionally opinionated to promote a standardization of we manage infra.
You should adhere to this definition as much as possible.

#### Why is bootstrap infrastructure state not kept in version control ?

//TODO: If you lose it, you lose a backup recovery mechanism. Prevent accidental deletion in CI/CD

