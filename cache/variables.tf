variable "cache_bucket_name" {
  type        = string
  description = "The bucket name of the S3 cache bucket"
}

variable "cache_expiration_days" {
  description = "Number of days before cache objects expires."
  type        = number
  default     = 1
}

variable "create_cache_bucket" {
  description = "This module is by default included in the runner module. To disable the creation of the bucket this parameter can be disabled."
  type        = string
  default     = true
}
