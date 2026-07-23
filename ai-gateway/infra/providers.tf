provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "ai-gateway"
    }
  }
}
