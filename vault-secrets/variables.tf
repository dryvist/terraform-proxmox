# Length for generated service credentials (passwords + API tokens). One knob
# for every password/token so lengths are never hardcoded per-resource; the
# value applied is a config concern, not visible at the use site. Keys that need
# a specific length for functional reasons (e.g. a Django SECRET_KEY) set their
# own and do not use this.
variable "credential_length" {
  description = "Character length for generated service passwords and API tokens"
  type        = number
  default     = 40
}
