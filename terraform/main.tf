# create main archive with cloud provider, versions and aws-key-pair for SSH access

terraform {

  required_version = ">1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


resource "aws_key_pair" "aws-munai-key" {
  key_name   = "aws-key-munai"
  public_key = file("./aws-key-challenge.pub")

}






