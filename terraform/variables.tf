variable "prefix" {
  type = string
}

variable "computer_name" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type = string
  sensitive = true
}

variable "local_ssh_key_path" {
  type = string
}

variable "my_ip_address" {
  type = string
}

variable "app_port" {
  type = string
  sensitive = true
}

variable "db_name" {
  type    = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}
