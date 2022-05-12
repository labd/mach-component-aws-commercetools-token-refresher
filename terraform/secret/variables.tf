variable "name" {}

variable "site" {}

variable "scopes" {
  type = list(string)
}

variable "kms_key_id" {
  default = null
}
