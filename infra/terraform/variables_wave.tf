variable "wave_registry_server" {
  default = "https://index.docker.io/v2/"
}

variable "wave_registry_username" {
}

variable "wave_registry_password" {
}

variable "wave_app_replicas" {
  default = 2
}

variable "wave_db_replica_count" {
  default = 1
}

variable "wave_redis_replica_count" {
  default = 2
}

variable "wave_db_name" {
  default = "db_example"
}

variable "wave_db_user" {
  default = "user_example"
}

variable "wave_db_password" {
  default = "password_example"
}

variable "wave_redis_password" {
  default = "password_example"
}

variable "wave_app_key" {
  default = "base64:8dQ7xw/kM9EYMV4cUkzKgET8jF4P0M0TOmmqN05RN2w="
}

variable "wave_app_jwt_secret" {
  default = "Jrsweag3Mf0srOqDizRkhjWm5CEFcrBy"
}

variable "wave_app_name" {
  default = "HaakCo Wave"
}

variable "wave_app_name_env" {
  default = "production"
}
variable "wave_app_debug" {
  default = "false"
}

variable "wave_app_log_level" {
  default = "debug"
}

variable "wave_app_mail_host" {
  default = "smtp.mailtrap.io"
}
variable "wave_app_mail_port" {
  default = "2525"
}
variable "wave_app_mail_username" {
  default = ""
}
variable "wave_app_mail_password" {
  default = ""
}
variable "wave_app_mail_encryption" {
  default = "null"
}
variable "wave_app_trusted_proxies" {
  default = "'10.0.0.0/8,172.16.0.0./12,192.168.0.0/16'"
}
