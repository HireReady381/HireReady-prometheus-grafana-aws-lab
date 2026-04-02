terraform {
  backend "s3" {
    bucket         = "HireReady-feb-2026-batch"
    key            = "HireReady/monitoring/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
