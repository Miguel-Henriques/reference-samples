resource "aws_ecr_repository" "authorizer" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "authorizer" {
  repository = aws_ecr_repository.authorizer.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the 5 most recent images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = { type = "expire" }
      }
    ]
  })
}
