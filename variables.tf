variable "name" {
  description = "Name to be used on all resources as prefix"
  default     = "test"
  type        = string
}

variable "env" {
  description = "Environment name"
  default     = "dev"
  type        = string
}

variable "vpc_cider" {
  description = "VPC cider"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_ciders" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "private_ciders" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "database_ciders" {
  description = "A list of database subnets"
  type        = list(string)
  default     = []
}

variable "ec2_number_of_instances" {
  description = "Number of ec2 instances to launch"
  type        = number
  default     = 1
}

variable "ec2_ami" {
  description = "ID of AMI to use for the instance"
  default     = "ami-089cc16f7f08c4457"
  type        = string
}

variable "ec2_instance_type" {
  description = "The type of instance to start"
  default     = "t2.micro"
  type        = string
}
