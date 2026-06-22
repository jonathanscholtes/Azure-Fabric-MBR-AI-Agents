<#
.SYNOPSIS
    Create the LONGHAUL Fabric Data Agent connected to the lh_trucking_ops Lakehouse.

.DESCRIPTION
    Uses the Fabric REST API to create 'da_trucking_ops' (idempotent).
    The Data Agent exposes the Lakehouse SQL analytics endpoint to AI Foundry agents
    via natural language queries - no Semantic Model required.

    Optionally writes fabric-data-agent-id and fabric-data-agent-url to Key Vault
    so Deploy-FoundryAgents.ps1 can pass them to agents/deploy.py at runtime.

.PARAMETER WorkspaceId
    Fabric workspace GUID.

.PARAMETER LakehouseId
    Fabric Lakehouse item GUID (lh_trucking_ops).

.PARAMETER DataAgentName
    Display name for the Data Agent. Default: da_trucking_ops

.PARAMETER KeyVaultUri
    Key Vault URI to store fabric-data-agent-id and fabric-data-agent-url secrets.
    Optional - skipped when not provided.

.PARAMETER AppIdentityPrincipalId
    Object (principal) ID of the app managed identity to add as Contributor in the
    Fabric workspace.  This is the principal_id (object ID), not the client_id.
    Optional - skipped when not provided.

.OUTPUTS
    PSCustomObject with DataAgentId and DataAgentUrl.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]  [string]$WorkspaceId,
    [Parameter(Mandatory=$true)]  [string]$LakehouseId,
    [string]$DataAgentName          = "da_trucking_ops",
    [string]$KeyVaultUri            = "",
    [string]$AppIdentityPrincipalId = "",
    # Foundry project ARM resource id — used to create the fabric_dataagent connection
    # the agents bind to. Pass the ai_project_id Terraform output.
    [string]$AiProjectId            = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\common\DeploymentFunctions.psm1" -Force

$fabricBase = "https://api.fabric.microsoft.com/v1"

# ---------------------------------------------------------------------------
# Fabric bearer token
# ---------------------------------------------------------------------------
Write-Info "Acquiring Fabric API token..."
$token = (az account get-access-token `
    --resource "https://api.fabric.microsoft.com" `
    --query accessToken -o tsv 2>$null).Trim()

if (-not $token) {
    throw "Could not acquire Fabric API token. Run 'az login'."
}

$headers = @{ "Authorization" = "Bearer $token" }

# ---------------------------------------------------------------------------
# Grant app managed identity Contributor role on the Fabric workspace
# ---------------------------------------------------------------------------
if ($AppIdentityPrincipalId) {
    Write-Title "Fabric Workspace RBAC  -  managed identity Contributor"
    Write-Info "Adding principal '$AppIdentityPrincipalId' as Contributor on workspace '$WorkspaceId'..."

    $rbacBody = @{
        principal = @{ id = $AppIdentityPrincipalId; type = "ServicePrincipal" }
        role      = "Contributor"
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        $null = Invoke-RestMethod `
            -Uri         "$fabricBase/workspaces/$WorkspaceId/roleAssignments" `
            -Headers     $headers `
            -Method      Post `
            -Body        ([System.Text.Encoding]::UTF8.GetBytes($rbacBody)) `
            -ContentType "application/json" `
            -ErrorAction Stop
        Write-Success "Managed identity added as Fabric workspace Contributor."
    } catch {
        $statusCode  = $null
        $errContent  = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $stream     = $_.Exception.Response.GetResponseStream()
                $reader     = New-Object System.IO.StreamReader($stream)
                $errContent = $reader.ReadToEnd()
            } catch {}
        }
        # 400 with PrincipalAlreadyHasRole means idempotent - treat as success
        if ($statusCode -eq 400 -and $errContent -match "PrincipalAlreadyHasRole") {
            Write-Info "Managed identity is already a workspace Contributor - no change needed."
        } elseif ($statusCode -eq 403) {
            Write-Warn "RBAC assignment failed (403 Forbidden)."
            Write-Warn "  Ensure 'Allow service principals and managed identities to use Fabric APIs'"
            Write-Warn "  is enabled in the Fabric Admin portal (Tenant settings)."
            Write-Warn "  Then re-run, or add the managed identity manually in the Fabric workspace."
        } else {
            Write-Warn "RBAC assignment failed (status=$statusCode): $errContent"
            Write-Warn "  Add managed identity '$AppIdentityPrincipalId' as Contributor manually in the Fabric workspace."
        }
    }
} else {
    Write-Info "AppIdentityPrincipalId not provided - skipping workspace RBAC assignment."
}

# ---------------------------------------------------------------------------
# Helper: poll Fabric LRO
# ---------------------------------------------------------------------------
function Wait-FabricOperation {
    param([string]$OperationUrl, [int]$TimeoutSeconds = 180)
    $elapsed = 0; $interval = 10
    while ($elapsed -lt $TimeoutSeconds) {
        Start-Sleep -Seconds $interval
        $elapsed += $interval
        $resp   = Invoke-RestMethod -Uri $OperationUrl -Headers $headers -Method Get -ContentType "application/json" -ErrorAction Stop
        $status = $resp.status
        Write-Info "  ${elapsed}s - status: $status"
        if ($status -eq "Succeeded") { return $resp }
        if ($status -in @("Failed","Cancelled")) { throw "Fabric operation failed: $($resp | ConvertTo-Json -Compress)" }
    }
    throw "Fabric LRO timed out after ${TimeoutSeconds}s."
}

# ---------------------------------------------------------------------------
# Check if Data Agent already exists
# ---------------------------------------------------------------------------
Write-Title "Fabric Data Agent  -  $DataAgentName"

$listUrl   = "$fabricBase/workspaces/$WorkspaceId/dataAgents"
$existing  = $null

try {
    $listResp = Invoke-RestMethod -Uri $listUrl -Headers $headers -Method Get -ContentType "application/json" -ErrorAction Stop
    $existing  = $listResp.value | Where-Object { $_.displayName -eq $DataAgentName }
} catch {
    Write-Warn "Could not list Data Agents (non-fatal): $_"
}

$dataAgentId = $null

if ($existing) {
    $dataAgentId = $existing.id
    Write-Info "Data Agent '$DataAgentName' already exists (id: $dataAgentId)"
} else {
    # -----------------------------------------------------------------------
    # Step 1: Create bare Data Agent (displayName + description only)
    # Fabric rejects definition in the initial POST for Data Agents;
    # definition (entities + instructions) is applied via updateDefinition.
    # -----------------------------------------------------------------------
    Write-Info "Creating Data Agent '$DataAgentName'..."

    $createBody = @{
        displayName = $DataAgentName
        description = "LONGHAUL trucking operations data agent - queries lh_trucking_ops Lakehouse"
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        $createResp = Invoke-WebRequest `
            -Uri             "$fabricBase/workspaces/$WorkspaceId/dataAgents" `
            -Headers         $headers `
            -Method          Post `
            -Body            ([System.Text.Encoding]::UTF8.GetBytes($createBody)) `
            -ContentType     "application/json" `
            -UseBasicParsing `
            -ErrorAction     Stop
    } catch {
        $errBody = $null
        if ($_.Exception.Response) {
            try {
                $stream  = $_.Exception.Response.GetResponseStream()
                $reader  = New-Object System.IO.StreamReader($stream)
                $errBody = $reader.ReadToEnd()
            } catch {}
        }
        $detail = if ($errBody) { " - $errBody" } else { "" }
        throw "Data Agent creation failed: $_$detail"
    }

    if ($createResp.StatusCode -eq 201) {
        $dataAgentId = ($createResp.Content | ConvertFrom-Json).id
        Write-Success "Data Agent created (id: $dataAgentId)"
    } elseif ($createResp.StatusCode -eq 202) {
        $operationUrl = $createResp.Headers["Location"]
        if (-not $operationUrl) {
            $opId         = $createResp.Headers["x-ms-operation-id"]
            $operationUrl = "$fabricBase/operations/$opId"
        }
        Write-Info "Data Agent provisioning async - polling..."
        $null = Wait-FabricOperation -OperationUrl $operationUrl

        $listResp    = Invoke-RestMethod -Uri $listUrl -Headers $headers -Method Get -ContentType "application/json" -ErrorAction Stop
        $created     = $listResp.value | Where-Object { $_.displayName -eq $DataAgentName }
        if (-not $created) { throw "Data Agent not found after async creation." }
        $dataAgentId = $created.id
        Write-Success "Data Agent provisioned (id: $dataAgentId)"
    } else {
        throw "Unexpected status $($createResp.StatusCode) from Fabric create Data Agent."
    }

    # -----------------------------------------------------------------------
    # Step 2: Apply definition (Lakehouse entity + system instructions)
    # -----------------------------------------------------------------------
    Write-Info "Applying Data Agent definition (entities + instructions)..."

    $dataAgentJson = @{
        entities = @(
            @{
                name        = "lh_trucking_ops"
                type        = "Lakehouse"
                workspaceId = $WorkspaceId
                artifactId  = $LakehouseId
            }
        )
        instructionSets = @(
            @{
                role         = "Agent"
                instructions = "You are da_trucking_ops, the data agent for LONGHAUL, a long-haul trucking company. You have access to 13 months of operational KPI data (May 2024 to May 2025) across 5 regions (North, South, East, West, Central) and 4 vehicle types (Flatbed, Refrigerated, Dry Van, Tanker). Available tables: dim_month (time dimension), dim_region (region dimension), dim_vehicle_type (vehicle type dimension), fact_monthly_kpis (monthly KPIs per region), fact_vehicle_kpis (monthly KPIs per region and vehicle type). period_label uses a 3-letter month abbreviation: 'Mar 2025', 'Feb 2025', 'Nov 2024'. Never use the full month name ('March 2025' returns no data). Always join fact tables with dimension tables to return human-readable labels. Use SUM() for fact columns and GROUP BY when aggregating across dimensions. Express financial values in dollars. Express miles as whole numbers. When comparing periods, calculate percentage change and indicate direction."
            }
        )
    } | ConvertTo-Json -Depth 10 -Compress

    $encodedDefinition = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dataAgentJson))

    $updateBody = @{
        definition = @{
            parts = @(
                @{
                    path        = "dataAgent.json"
                    payload     = $encodedDefinition
                    payloadType = "InlineBase64"
                }
            )
        }
    } | ConvertTo-Json -Depth 10 -Compress

    try {
        $updateResp = Invoke-WebRequest `
            -Uri             "$fabricBase/workspaces/$WorkspaceId/dataAgents/$dataAgentId/updateDefinition" `
            -Headers         $headers `
            -Method          Post `
            -Body            ([System.Text.Encoding]::UTF8.GetBytes($updateBody)) `
            -ContentType     "application/json" `
            -UseBasicParsing `
            -ErrorAction     Stop

        if ($updateResp.StatusCode -in @(200, 201)) {
            Write-Success "Data Agent definition applied."
        } elseif ($updateResp.StatusCode -eq 202) {
            $opUrl = $updateResp.Headers["Location"]
            if (-not $opUrl) {
                $opId  = $updateResp.Headers["x-ms-operation-id"]
                $opUrl = "$fabricBase/operations/$opId"
            }
            Write-Info "Definition update async - polling..."
            $null = Wait-FabricOperation -OperationUrl $opUrl
            Write-Success "Data Agent definition update complete."
        }
    } catch {
        Write-Warn "Could not apply definition via updateDefinition: $_"
        Write-Info "Data Agent exists but Lakehouse entity + instructions must be configured in the Fabric portal."
        Write-Info "  Fabric portal > Data Agents > $DataAgentName > Edit"
    }
}

# ---------------------------------------------------------------------------
# Build inference URL (chat completions endpoint)
# ---------------------------------------------------------------------------
$dataAgentUrl = "$fabricBase/workspaces/$WorkspaceId/dataAgents/$dataAgentId/chat/completions"
Write-Info "Data Agent URL: $dataAgentUrl"

# ---------------------------------------------------------------------------
# Store in Key Vault (optional)
# ---------------------------------------------------------------------------
if ($KeyVaultUri) {
    $kvName = ($KeyVaultUri -split '\.')[0] -replace 'https://',''
    Write-Info "Storing Data Agent secrets in Key Vault '$kvName'..."

    az keyvault secret set --vault-name $kvName --name "fabric-data-agent-id"  --value $dataAgentId  --output none
    az keyvault secret set --vault-name $kvName --name "fabric-data-agent-url" --value $dataAgentUrl --output none

    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Key Vault secret write failed - continuing without KV storage."
    } else {
        Write-Success "Secrets written: fabric-data-agent-id, fabric-data-agent-url"
    }
}

# ---------------------------------------------------------------------------
# Set WorkspaceId + ArtifactId on the Foundry fabric_dataagent connection.
# Terraform creates the connection shell (metadata.type = "fabric_dataagent_preview",
# target "-", no credentials) — that discriminator is what makes Foundry expose it as a
# Fabric Data Agent tool. The Workspace/Artifact IDs depend on the Data Agent created
# above (its GUID is the ArtifactId), so they are set here via a full-body PUT that
# re-asserts the metadata and adds the credentials. (No delete -> no secret purge.)
# ---------------------------------------------------------------------------
if ($AiProjectId) {
    Write-Title "Foundry connection  -  fabric_dataagent (set Workspace/Artifact)"
    $connUrl  = "https://management.azure.com$AiProjectId/connections/fabric_dataagent?api-version=2025-09-01"
    $connBody = @{
        properties = @{
            category                    = "CustomKeys"
            authType                    = "CustomKeys"
            target                      = "-"
            isSharedToAll               = $false
            useWorkspaceManagedIdentity = $false
            peRequirement               = "NotRequired"
            peStatus                    = "NotApplicable"
            credentials                 = @{ keys = @{ WorkspaceId = $WorkspaceId; ArtifactId = $dataAgentId } }
            metadata                    = @{ type = "fabric_dataagent_preview" }
        }
    } | ConvertTo-Json -Depth 8 -Compress

    $connTmp = [System.IO.Path]::GetTempFileName()
    $connBody | Out-File -FilePath $connTmp -Encoding utf8
    az rest --method put --url $connUrl --headers "Content-Type=application/json" --body "@$connTmp" --output none
    $connExit = $LASTEXITCODE
    Remove-Item $connTmp -Force
    if ($connExit -ne 0) {
        Write-Warn "Could not set Workspace/Artifact on the 'fabric_dataagent' connection (exit $connExit)."
        Write-Info  "Set them manually: Foundry portal > Tools > fabric_dataagent > Edit (WorkspaceId=$WorkspaceId, ArtifactId=$dataAgentId)."
    } else {
        Write-Success "fabric_dataagent connection updated (WorkspaceId=$WorkspaceId, ArtifactId=$dataAgentId)."
    }
} else {
    Write-Warn "AiProjectId not supplied - skipping fabric_dataagent Workspace/Artifact update."
    Write-Info  "Pass -AiProjectId (the ai_project_id Terraform output)."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Fabric Data Agent Ready ===" -ForegroundColor Cyan
Write-Host "  Workspace ID  : $WorkspaceId"  -ForegroundColor Gray
Write-Host "  Data Agent ID : $dataAgentId"  -ForegroundColor Gray
Write-Host "  URL           : $dataAgentUrl" -ForegroundColor Green
Write-Host ""

[PSCustomObject]@{
    DataAgentId  = $dataAgentId
    DataAgentUrl = $dataAgentUrl
}
