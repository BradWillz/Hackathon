# Global Variables
variable "tenant_id" {
  description = "The tenant id of this deployment"
  type        = string
  default     = "baaac9df-59e5-4039-a9e5-668ff153fac9"
}
variable "subscription_id" {
  description = "The subscription id of this deployment"
  type        = string
  default     = "cc1cd9f2-f5f9-43cf-8fef-1da6a299ae77"
}
variable "location" {
  description = "The location used for the deployment"
  type        = string
  default     = "UK South"
}
variable "location_short" {
  description = "The location used for the deployment"
  type        = string
  default     = "uks"
}
variable "resource_prefix" {
  description = "Shorthand service for the deployment"
  type        = string
  default     = "team4"
}
variable "environment" {
  description = "Enviroment for the deployment"
  type        = string
  default     = "prod"
}
variable "environment_short" {
  description = "Enviroment for the deployment"
  type        = string
  default     = "prd"
}
## Tagging ##
variable "tag_owner" {
  description = "Sets the value of this tag"
  type        = string
  default     = "IT Infrastructure"
}

variable "tag_environment" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Production"
}

variable "tag_application" {
  description = "Sets the value of this tag"
  type        = string
  default     = "IT Infrastructure"
}

variable "tag_criticality" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Tier 1"
}

variable "tag_cost_centre" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Unassigned"
}

variable "tag_project_code" {
  description = "Sets the value of this tag"
  type        = string
  default     = "Unassigned"
}

locals {
  tags = merge(
    {
      Owner          = var.tag_owner
      Environment    = var.tag_environment
      Application    = var.tag_application
      Criticality    = var.tag_criticality
      "Cost Centre"  = var.tag_cost_centre
      "Project Code" = var.tag_project_code
    }
  )
}