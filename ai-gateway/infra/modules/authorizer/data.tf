# The upstream LiteLLM module exposes no VPC/subnet/SG outputs, but it tags
# every resource with `litellm:stack = <tenant>-litellm-<env>` and names
# subnets deterministically, so the network is discovered here by tag. See
# docs/02-gateway-topology.md for why the authorizer shares that VPC.

data "aws_vpc" "litellm" {
  tags = {
    "litellm:stack" = var.litellm_stack_name
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.litellm.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.litellm_stack_name}-private-*"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.litellm.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.litellm_stack_name}-public-*"]
  }
}

data "aws_ecs_cluster" "litellm" {
  cluster_name = var.litellm_ecs_cluster_name
}
