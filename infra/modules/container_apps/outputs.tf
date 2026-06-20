output "insights_api_fqdn" {
  description = "Public FQDN of the insights-api Container App"
  value       = azurerm_container_app.insights_api.ingress[0].fqdn
}

output "presentation_tools_fqdn" {
  description = "Internal FQDN of the presentation-tools Container App (ACA internal ingress — agents only)"
  value       = azurerm_container_app.presentation_tools.ingress[0].fqdn
}

output "longhaul_ui_fqdn" {
  description = "Public FQDN of the insights-ui Container App"
  value       = azurerm_container_app.longhaul_ui.ingress[0].fqdn
}

output "container_app_environment_id" {
  description = "Resource ID of the Container App Environment"
  value       = azurerm_container_app_environment.main.id
}
