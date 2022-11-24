# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.9.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }

  # ToDo: Variables are not allowed here. Create a file backend.conf to parametrize this for different stages -> https://stackoverflow.com/questions/65838989/variables-may-not-be-used-here-during-terraform-init
  # Comment for local deployments
  # backend "azurerm" {
  #   resource_group_name  = "yourresourcegroupname"
  #   storage_account_name = "yourstorageaccount"
  #   container_name       = "yourapp-tfstate-dev"
  #   key                  = "tfstate"
  # }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.region
}


### Create App Registration, with app roles and secret
resource "azuread_application" "app_registration" {
  display_name     = "YourWebApp"
  owners           = [data.azurerm_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  app_role {
    allowed_member_types = ["User"]
    description          = "Admins can manage roles and perform all task actions"
    display_name         = "Admin"
    enabled              = true
    value                = "Task.Admin"
    id                   = "1bfc780e-e2b3-4131-a3a5-5efe8393ad0d"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "User roles have limited query access"
    display_name         = "User"
    enabled              = true
    value                = "Task.User"
    id                   = "893fdbd8-2e95-448a-84ee-a653e9685c75"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "Partner roles are Users that can also manage partners"
    display_name         = "Partner"
    enabled              = true
    value                = "Task.Partner"
    id                   = "43c20932-bcc4-4b93-9a0f-28e95670c50f"

  }

  feature_tags {
    enterprise = true
  }
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    ### Important: Admin consent is needed anyway
    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }
  }

  web {
    homepage_url  = "https://${var.app_service_name}.azurewebsites.net"
    logout_url    = "https://${var.app_service_name}.azurewebsites.net/account/logout"
    redirect_uris = ["https://localhost:7244/authentication/login-callback", "https://${var.app_service_name}.azurewebsites.net/authentication/login-callback", "https://localhost:44348/signin-oidc", "https://${var.app_service_name}.azurewebsites.net/signin-oidc"]
  }
}

# ToDo: Add secret rotation
# resource "time_rotating" "rotating_weekly" {
#   rotation_days = 7
# }
resource "azuread_application_password" "app_secret" {
  application_object_id = azuread_application.app_registration.object_id
  # rotate_when_changed = {
  #   rotation = time_rotating.rotating_weekly.id
  # }
}


# Create Key Vault
# Secrets and certificates should be manually uploaded to the app registration and later on update the values in this tenant
resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  depends_on = [
    azuread_application.app_registration,
    azuread_application_password.app_secret
  ]

  sku_name = "standard"

  access_policy = [
    {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = data.azurerm_client_config.current.object_id

      secret_permissions = [
        "Get",
        "List",
        "Purge",
        "Recover",
        "Restore",
        "Set",
        "Delete"
      ]

      certificate_permissions = [
        "Get",
        "GetIssuers",
        "List",
        "ListIssuers",
        "Update",
        "Create",
        "SetIssuers",
        "ManageIssuers",
        "Delete"
      ]

      application_id      = null
      key_permissions     = null
      storage_permissions = null
    },
    {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = azurerm_linux_web_app.my_web_app.identity[0].principal_id

      secret_permissions = [
        "Get",
        "List",
      ]

      certificate_permissions = [
        "Get",
        "List",
      ]

      application_id      = null
      key_permissions     = null
      storage_permissions = null
    }
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

# Database
## Generate random pwd
resource "random_password" "sql" {
  length           = 24
  lower            = true
  min_lower        = 1
  number           = true
  min_numeric      = 1
  special          = true
  min_special      = 1
  override_special = "!$#%"
  upper            = true
  min_upper        = 1
}

## SQL Server Instance
resource "azurerm_mssql_server" "azure_sql_server_instance" {
  name                = var.sql_server_instance_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  version             = "12.0"
  minimum_tls_version = "1.2"

  administrator_login          = "db-admin"
  administrator_login_password = random_password.sql.result

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}
## Database
resource "azurerm_mssql_database" "db" {
  name        = var.database_name
  server_id   = azurerm_mssql_server.azure_sql_server_instance.id
  max_size_gb = 10
  sku_name    = var.database_sku_name

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}


## DB Firewall
resource "azurerm_mssql_firewall_rule" "db_fw" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.azure_sql_server_instance.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# App plan
resource "azurerm_service_plan" "appplan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  sku_name            = var.app_service_plan_sku_name
  os_type             = "Linux"

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}


# App service
resource "azurerm_linux_web_app" "my_web_app" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  service_plan_id     = azurerm_service_plan.appplan.id

  site_config {
    always_on = false

    application_stack {
      dotnet_version = "6.0"
    }
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = var.aspnetcore_environment
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
}

## Add connection string in the kv
resource "azurerm_key_vault_secret" "secret_db_connection_string" {
  name         = "ConnectionStrings--SqlConnection"
  value        = "Server=tcp:${azurerm_mssql_server.azure_sql_server_instance.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.azure_sql_server_instance.administrator_login};Password=${azurerm_mssql_server.azure_sql_server_instance.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_mssql_database.db]
}

## Add connection string in the kv
resource "azurerm_key_vault_secret" "client_secret_value" {
  name         = "AzureAd--ClientSecret"
  value        = azuread_application_password.app_secret.value
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azuread_application_password.app_secret]
}
