terraform {
  backend "s3" {
    bucket         = "pathnex-feb-2026-batch"
    key            = "pathnex/monitoring/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}