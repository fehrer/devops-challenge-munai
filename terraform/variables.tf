# create varibles

variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "ami-instance" {
  description = "Default AMI for our resources"
  type        = string
  default     = "ami-0e86e20dae9224db8"

}