variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "ssh_public_key_path" {
  type    = string
  default = "/Users/owner/.ssh/lab_jenkins_key.pub"

}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the instance"
  type        = string
  default     = "lab_jenkins_key" # Optional: set a default key name
}

variable "root_volume_size" {
  description = "The size of the root volume in GB"
  type        = number
  default     = 30
}
