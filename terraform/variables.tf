variable "db_username" {
  description = "Postgres username"
  type        = string
  default     = "grafana"
  sensitive   = true
}

variable "db_password" {
  description = "Postgres password"
  type        = string
  default     = random_password.db_password.result
  sensitive   = true
}