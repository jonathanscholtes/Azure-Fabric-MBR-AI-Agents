# Lookup the user-assigned identity by name (derived from resource ID) to get client_id
data "azurerm_user_assigned_identity" "app" {
  resource_group_name = var.resource_group_name
  name                = split("/", var.identity_id)[length(split("/", var.identity_id)) - 1]
}

# ── ACA Environment ────────────────────────────────────────────────────────────
resource "azurerm_container_app_environment" "main" {
  name                = var.container_app_env_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# ── insights-api (external ingress, port 8000) ────────────────────────────────────
resource "azurerm_container_app" "insights_api" {
  name                         = "ca-insights-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  registry {
    server   = var.registry_server
    identity = var.identity_id
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "insights-api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_connection_string
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = data.azurerm_user_assigned_identity.app.client_id
      }
      env {
        name  = "FABRIC_SQL_SERVER"
        value = var.fabric_sql_server
      }
      env {
        name  = "FABRIC_SQL_DATABASE"
        value = var.fabric_sql_database
      }
      env {
        name  = "STORAGE_ACCOUNT_URL"
        value = "https://${var.storage_account_name}.blob.core.windows.net"
      }
      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = var.foundry_project_endpoint
      }
    }
  }
}

# ── presentation-tools (external ingress, port 80) ───────────────────────────────
resource "azurerm_container_app" "presentation_tools" {
  name                         = "ca-presentation-tools"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  registry {
    server   = var.registry_server
    identity = var.identity_id
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "presentation-tools"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_connection_string
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = data.azurerm_user_assigned_identity.app.client_id
      }
      env {
        name  = "STORAGE_ACCOUNT_URL"
        value = "https://${var.storage_account_name}.blob.core.windows.net"
      }
    }
  }
}

# ── insights-ui (external ingress, port 80) ───────────────────────────────────
resource "azurerm_container_app" "longhaul_ui" {
  name                         = "ca-insights-ui"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  registry {
    server   = var.registry_server
    identity = var.identity_id
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "insights-ui"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

    }
  }
}
