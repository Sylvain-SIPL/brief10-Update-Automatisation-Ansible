variable "create_rg" {
  description = "Indicate whether to create the resource group or not"
  type        = bool
  default     = true # Change to false if you want to skip creation
}

variable "location" {
  description = "location"
  default     = "northeurope"
}
