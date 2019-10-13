variable "cache_bucket_name" {
  type        = string
  description = "The bucket name of the S3 cache bucket"
}

variable "cache_expiration_days" {
  description = "Number of days before cache objects expires."
  type        = number
  default     = 1
}
