variable "name_prefix" { type = string }
variable "tags" { type = map(string) }

variable "vpc_cidr" { type = string }

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "enable_vpc_endpoints" {
  type = bool
}
