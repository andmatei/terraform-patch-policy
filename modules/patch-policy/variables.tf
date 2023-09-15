variable "install_patches" {
  type        = bool
  default     = false
  description = "Automatically install any missing patches"
}

variable "scan_cutoff" {
  default     = 1
  description = "The number of hours before the end of the Scanning Maintenance Window that Systems Manager stops scheduling new tasks for execution"
  type        = number
}

variable "install_cutoff" {
  default     = 1
  description = "The number of hours before the end of the Patching Maintenance Window that Systems Manager stops scheduling new tasks for execution"
  type        = number
}

variable "scan_duration" {
  default     = 4
  description = "The duration of the Scanning Maintenance Window in hours."
  type        = number
}

variable "install_duration" {
  default     = 4
  description = "The duration of the Patching Maintenance Window in hours."
  type        = number
}

variable "scan_schedule" {
  type        = string
  default     = "cron(0 1 * * ? *)"
  description = "6-field Cron expression describing the patch scanning schedule"
}

variable "install_schedule" {
  type        = string
  default     = "cron(0 2 ? * SUN *)"
  description = "6-field Cron expression describing the installing maintenance schedule"
}

variable "regions" {
  type        = list(string)
  default     = local.available_regions
  description = "Regions in which the patch policy is deployed to"

  validation {
    error_message = "Region not supported."

    condition = (
      toset(var.regions) == setintersection(
        var.regions,
        local.available_regions
      )
    )
  }
}

variable "instance_tag" {
  type = object({
    key   = string
    value = string
  })

  default     = null
  description = "Tag key-value pair to select the nodes in the account to patch"
}

# TODO: Add variables to specify concurrency settings

# TODO: Add variables to specify path baselines


