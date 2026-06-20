subscription_id = "${SubscriptionId}"
tenant_id       = "${TenantId}"
location        = "${Location}"
environment     = "${Environment}"
resource_token  = "${ResourceToken}"

# ---------------------------------------------------------------------------
# Naming convention: <caf-abbr>-ins-<env>-<token>
# Token prevents soft-delete conflicts on globally-scoped resources.
# Key Vault names are reserved for 90 days after destroy.
# ACR and Storage names are globally unique (alphanumeric only; no dashes).
# ---------------------------------------------------------------------------

resource_group_name = "rg-ins-${Environment}-${ResourceToken}"

# Identity
app_identity_name    = "id-ins-${Environment}-app"
deploy_identity_name = "id-ins-${Environment}-deploy"

# Secrets
key_vault_name = "kv-ins-${Environment}-${ResourceToken}"

# Observability
app_insights_name            = "appi-ins-${Environment}-${ResourceToken}"
log_analytics_workspace_name = "log-ins-${Environment}-${ResourceToken}"

# AI Foundry
ai_services_name = "ais-ins-${Environment}-${ResourceToken}"
ai_project_name  = "proj-ins-${Environment}-${ResourceToken}"

# Container infrastructure
# ACR: alphanumeric only (no dashes), 5-50 chars
# Storage: alphanumeric lowercase only (no dashes), 3-24 chars
container_registry_name = "crins${ResourceToken}"
storage_account_name    = "sains${Environment}${ResourceToken}"
container_app_env_name  = "cae-ins-${Environment}-${ResourceToken}"

# ---------------------------------------------------------------------------
# Fabric (populated by Deploy-FabricWorkspace.ps1 or supplied manually)
# ---------------------------------------------------------------------------
fabric_workspace_id = "${FabricWorkspaceId}"
fabric_artifact_id  = "${FabricArtifactId}"
fabric_sql_server   = "${FabricSqlServer}"
fabric_sql_database = "lh_trucking_ops"

# ---------------------------------------------------------------------------
# GitHub OIDC (populated by New-GitHubOidc.ps1 or -SetupGitHub flag)
# ---------------------------------------------------------------------------
github_org        = "${GitHubOrg}"
github_repository = "${GitHubRepository}"

tags = {
  project     = "longhaul-insights-ai-agents"
  environment = "${Environment}"
}
