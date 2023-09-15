variable "account_name" {
  type        = string
  description = "Name of the account"
}

variable "email_domain" {
  type        = string
  description = "Email domain"

  validation {
    condition = can(regex("^[A-Z0-9.-]+.[A-Z]{2,}$"))
  }
}
