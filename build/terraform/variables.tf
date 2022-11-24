variable "resource_group_name" {
  default = "non-set" # Set in specific environment tfvars
}

variable "app_service_name" {
  default = "non-set" # Set in specific environment tfvars
}

variable "sql_server_instance_name" {
  default = "non-set" # Set in specific environment tfvars
}

variable "database_sku_name" {
  default = "S0" # Set in specific environment tfvars
}

variable "app_service_plan_name" {
  default = "AppServicePlanSBS" # Set in specific environment tfvars
}

variable "app_service_plan_sku_name" {
  default = "F1" # Set in specific environment tfvars
}

variable "key_vault_name" {
  default = "non-set"
}

variable "database_name" {
  default = "non/set"
}

variable "region" {
  default = "switzerlandnorth"
}

variable "aspnetcore_environment" {
  default = "non-set"
}

variable "rg_tag_cost_center" {
  default = "non-set"
}

variable "rg_tag_customer" {
  default = "non-set"
}

variable "rg_tag_department" {
  default = "non-set"
}

variable "rg_tag_owner" {
  default = "non-set"
}




