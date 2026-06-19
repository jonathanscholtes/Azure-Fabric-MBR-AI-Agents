<#
.SYNOPSIS
    Creates an Entra ID app registration + federated credential for GitHub Actions OIDC
    and writes the three required secrets directly to the GitHub repository.

.PARAMETER Repo
    GitHub repo in owner/name format. Auto-detected from git remote origin if omitted.

.PARAMETER AppName
    Entra app registration display name.

.PARAMETER Environment
    GitHub Actions environment name (dev | staging | prod).
    Creates an environment-scoped federated credential.

.EXAMPLE
    .\scripts\New-GitHubOidc.ps1
    .\scripts\New-GitHubOidc.ps1 -Environment staging
    .\scripts\New-GitHubOidc.ps1 -Repo myorg/Azure-Fabric-MBR-AI-Agents -Environment prod
#>

param (
    [string] $Repo        = '',
    [string] $AppName     = 'longhaul-github-actions',
    [string] $Environment = 'dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve repo from git remote if not supplied
# ---------------------------------------------------------------------------
if (-not $Repo) {
    $remote = git remote get-url origin 2>$null
    if ($remote -match 'github\.com[:/](.+?)(?:\.git)?$') {
        $Repo = $Matches[1]
        Write-Host "Auto-detected repo: $Repo" -ForegroundColor Cyan
    } else {
        Write-Error "Could not detect GitHub repo from git remote. Pass -Repo 'owner/name'."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Resolve subscription / tenant from current az login
# ---------------------------------------------------------------------------
Write-Host "`nReading Azure account..." -ForegroundColor Cyan
$account        = az account show | ConvertFrom-Json
$subscriptionId = $account.id
$tenantId       = $account.tenantId
Write-Host "  Subscription : $subscriptionId"
Write-Host "  Tenant       : $tenantId"
Write-Host "  Repo         : $Repo"
Write-Host "  App name     : $AppName"
Write-Host "  Environment  : $Environment"

# ---------------------------------------------------------------------------
# Create (or reuse) app registration
# ---------------------------------------------------------------------------
Write-Host "`nChecking for existing app registration '$AppName'..." -ForegroundColor Cyan
$existingApps = az ad app list --display-name $AppName | ConvertFrom-Json

if ($existingApps.Count -gt 0) {
    $clientId = $existingApps[0].appId
    Write-Host "  Reusing existing app: $clientId" -ForegroundColor Yellow
} else {
    Write-Host "  Creating app registration..." -ForegroundColor Cyan
    $app      = az ad app create --display-name $AppName | ConvertFrom-Json
    $clientId = $app.appId
    Write-Host "  Created: $clientId" -ForegroundColor Green

    az ad sp create --id $clientId | Out-Null
    Write-Host "  Service principal created." -ForegroundColor Green

    Start-Sleep -Seconds 10
}

# ---------------------------------------------------------------------------
# Role assignments (idempotent)
# ---------------------------------------------------------------------------
$scope = "/subscriptions/$subscriptionId"

foreach ($role in @('Contributor', 'Storage Blob Data Contributor')) {
    Write-Host "  Assigning '$role'..." -ForegroundColor Cyan
    $existing = az role assignment list `
        --assignee $clientId --role $role --scope $scope `
        --query "[0].id" -o tsv 2>$null
    if ($existing) {
        Write-Host "    Already assigned." -ForegroundColor Yellow
    } else {
        az role assignment create `
            --assignee $clientId --role $role --scope $scope --output none
        Write-Host "    Assigned." -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Federated credential — environment-scoped (matches workflow_dispatch jobs)
# ---------------------------------------------------------------------------
Write-Host "`nConfiguring federated credential for environment '$Environment'..." -ForegroundColor Cyan

$credName    = "github-$($Repo -replace '[^a-zA-Z0-9]', '-')-$Environment"
$credSubject = "repo:${Repo}:environment:$Environment"

$existingCreds = az ad app federated-credential list --id $clientId | ConvertFrom-Json
$existing = @($existingCreds) | Where-Object {
    ($_ | Get-Member -Name subject -ErrorAction SilentlyContinue) -and $_.subject -eq $credSubject
}

if ($existing) {
    Write-Host "  Federated credential already exists." -ForegroundColor Yellow
} else {
    $credBody = @{
        name      = $credName
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = $credSubject
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Depth 5

    $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
    $credBody | Out-File -FilePath $tempFile -Encoding utf8

    az ad app federated-credential create --id $clientId --parameters "@$tempFile" --output none

    Remove-Item $tempFile -Force
    Write-Host "  Federated credential created (subject: $credSubject)." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Write secrets to GitHub repository
# ---------------------------------------------------------------------------
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "`nWARNING: 'gh' CLI not found - secrets not written automatically." -ForegroundColor Yellow
    Write-Host "Install from https://cli.github.com then run:" -ForegroundColor Gray
    Write-Host "  gh variable set AZURE_CLIENT_ID       --body $clientId       --repo $Repo" -ForegroundColor White
    Write-Host "  gh variable set AZURE_TENANT_ID       --body $tenantId       --repo $Repo" -ForegroundColor White
    Write-Host "  gh variable set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $Repo" -ForegroundColor White
} else {
    Write-Host "`nWriting secrets to $Repo..." -ForegroundColor Cyan

    # OIDC identifiers are not sensitive — write as repo variables (vars.*) so
    # the workflow can reference them as ${{ vars.AZURE_CLIENT_ID }} etc.
    gh variable set AZURE_CLIENT_ID       --body $clientId       --repo $Repo
    gh variable set AZURE_TENANT_ID       --body $tenantId       --repo $Repo
    gh variable set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $Repo

    # SP object ID is used by Terraform for role assignments — keep as a secret
    $spObjectId = az ad sp show --id $clientId --query id -o tsv 2>$null
    if ($spObjectId) {
        gh secret set AZURE_SP_OBJECT_ID --body $spObjectId --repo $Repo
    }

    Write-Host "  Variables and secrets written." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Done!  OIDC configured for $Repo ($Environment)"           -ForegroundColor Green
Write-Host ""
Write-Host "  AZURE_CLIENT_ID       = $clientId"                         -ForegroundColor Green
Write-Host "  AZURE_TENANT_ID       = $tenantId"                         -ForegroundColor Green
Write-Host "  AZURE_SUBSCRIPTION_ID = $subscriptionId"                   -ForegroundColor Green
Write-Host ""
Write-Host "  Next: run the Deploy workflow from GitHub Actions."         -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
