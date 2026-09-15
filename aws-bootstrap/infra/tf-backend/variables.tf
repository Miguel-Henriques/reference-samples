variable "project" {
  type        = string
  description = "(Required) Project name. Establishes a project-based boundary for the S3 Backend."
}

variable "module" {
  type        = string
  description = "(Required) Service module being developed under the project. Creates a folder with the name of the module under the project-bounded S3 Backend."
}

variable "region" {
  type        = string
  description = "(Required) AWS region where the S3 state bucket will be created."
}

variable "create" {
  type        = bool
  description = "(Optional) Whether to create the state bucket. Set to true if it doesn't exist, false if it does."
  default     = false
}
