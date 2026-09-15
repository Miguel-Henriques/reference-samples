#!/bin/bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $(basename "$0") <project> <module> [region]

Bootstrap an S3 Terraform backend for a project. The same AWS account can
bootstrap multiple backends, one per project.

Arguments:
  project   Project name (bucket: {account_id}-{project}-tf-backend)
  module    Module name (state key prefix: modules/{module})
  region    AWS region (default: eu-west-1)

Example:
  $(basename "$0") my-app shared eu-west-1
EOF
    exit 1
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

project="$1"
module="$2"
region="${3:-eu-west-1}"

if [ -z "$project" ] || [ -z "$module" ]; then
    print_error "Project and module are required."
    usage
fi

account_id=$(aws sts get-caller-identity --query "Account" --output text)
bucket_name="${account_id}-${project}-tf-backend"

print_info "Bootstrapping Terraform backend for project '${project}' in account ${account_id}..."
print_info "Module: ${module}, Region: ${region}"

if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
    create_var="false"
    print_info "Backend bucket '${bucket_name}' already exists. Generating backend config..."
else
    create_var="true"
    print_info "Creating backend infrastructure for project '${project}'..."
fi

# Create output directory if it doesn't exist
mkdir -p "./.out"

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
    print_info "Initializing Terraform..."
    terraform init
fi

# Run terraform apply with all required variables
terraform apply \
    -var="create=${create_var}" \
    -var="project=${project}" \
    -var="module=${module}" \
    -var="region=${region}" \
    -state="./.out/terraform.tfstate"

# Untrack state file to prevent state sync
rm ./.out/terraform.tfstate
