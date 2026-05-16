variable "region" {
    default = "eu-west-2"
}

variable "zone1" {
    default = "eu-west-2a"
}

variable "zone2" {
    default = "eu-west-2b"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  sensitive = true
}

variable "ingestion_image" {
  description = "ECR image URI for ingestion"
}

variable "validation_image" {
  description = "ECR image URI for validation"
}

variable "processing_image" {
  description = "ECR image URI for processing"
}