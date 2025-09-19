# DIGIT OSS Service Fix Script for Windows PowerShell
# Note: To run unsigned scripts like this one, you need to set the PowerShell execution policy to allow it.
# You can do that by running the following command in an elevated PowerShell prompt:
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
# This allows scripts to run without signature checks in the current user scope only.
param(
    [string]$ComposeProjectName = "digit-oss",
    [string]$NetworkName = "digit-network"
)

# Set environment variables
$env:COMPOSE_PROJECT_NAME = $ComposeProjectName
$env:NETWORK_NAME = $NetworkName

# Function to run docker compose commands
function Invoke-DockerCompose {
    param([string[]]$Arguments)
    
    $allArgs = @(
        "compose", "-p", $env:COMPOSE_PROJECT_NAME,
        "-f", "docker-compose.infra.yml",
        "-f", "docker-compose.services.yml"
    ) + $Arguments
    
    & docker @allArgs
}

# Logging functions
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Info "DIGIT OSS Service Fix Script"
Write-Host "====================================" -ForegroundColor Cyan

# Step 1: Stop all unhealthy services
Write-Info "1. Stopping unhealthy services..."
Invoke-DockerCompose @("stop", "nginx-gateway", "user", "workflow-v2", "billing-service", "collection-services", "notification-sms", "filestore", "egov-idgen")
Write-Success "Stopped unhealthy services"

# Step 2: Restart infrastructure services
Write-Info "2. Ensuring infrastructure is healthy..."
Invoke-DockerCompose @("restart", "postgres", "redis", "elasticsearch", "kafka")
Start-Sleep -Seconds 10

# Step 3: Check database connectivity
Write-Info "3. Testing database connectivity..."
try {
    $dbCheck = docker exec "$env:COMPOSE_PROJECT_NAME-postgres" pg_isready -U postgres -d egov
    if ($LASTEXITCODE -eq 0) {
        Write-Success "PostgreSQL is ready"
    } else {
        Write-Error "PostgreSQL is not ready - please check database configuration"
        exit 1
    }
} catch {
    Write-Error "Failed to check PostgreSQL status"
    exit 1
}

# Step 4: Restart services in dependency order
Write-Info "4. Restarting core services in correct order..."

# Start MDMS first
Write-Info "  Starting MDMS service..."
Invoke-DockerCompose @("up", "-d", "mdms-service")
Start-Sleep -Seconds 15

# Wait for MDMS to be healthy
Write-Info "  Waiting for MDMS to be healthy..."
$timeout = 60
$healthy = $false
while ($timeout -gt 0 -and -not $healthy) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8083/egov-mdms-service/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "MDMS service is healthy"
            $healthy = $true
            break
        }
    } catch {
        # Service not ready yet
    }
    Start-Sleep -Seconds 2
    $timeout -= 2
}

# Start User service
Write-Info "  Starting User service..."
Invoke-DockerCompose @("up", "-d", "user")
Start-Sleep -Seconds 20

# Start Access Control
Write-Info "  Starting Access Control..."
Invoke-DockerCompose @("up", "-d", "access-control")
Start-Sleep -Seconds 15

# Start Workflow service
Write-Info "  Starting Workflow service..."
Invoke-DockerCompose @("up", "-d", "workflow-v2")
Start-Sleep -Seconds 20

# Start remaining services
Write-Info "  Starting Billing service..."
Invoke-DockerCompose @("up", "-d", "billing-service")
Start-Sleep -Seconds 15

Write-Info "  Starting Collection service..."
Invoke-DockerCompose @("up", "-d", "collection-services")
Start-Sleep -Seconds 15

Write-Info "  Starting Notification SMS..."
Invoke-DockerCompose @("up", "-d", "notification-sms")
Start-Sleep -Seconds 10

Write-Info "  Starting ID Generation service..."
Invoke-DockerCompose @("up", "-d", "egov-idgen")
Start-Sleep -Seconds 15

Write-Info "  Starting Filestore service..."
Invoke-DockerCompose @("up", "-d", "filestore")
Start-Sleep -Seconds 15

# Step 5: Start nginx gateway last
Write-Info "5. Starting nginx gateway..."
Invoke-DockerCompose @("up", "-d", "nginx-gateway")
Start-Sleep -Seconds 10

# Step 6: Restart custom services
Write-Info "6. Restarting custom services..."
Invoke-DockerCompose @("restart", "permit-service", "vc-service")
Start-Sleep -Seconds 15

# Step 7: Final status
Write-Info "7. Checking final status..."
Start-Sleep -Seconds 10

Write-Host ""
Write-Success "Service restart complete!"
Write-Host ""

# Show service status
Write-Info "Current service status:"
docker ps --format "table {{.Names}}`t{{.Status}}" | Select-String $env:COMPOSE_PROJECT_NAME

Write-Host ""
Write-Info "Run '.\scripts\health-check.sh' or the health check script to verify all services are healthy"
Write-Host ""
Write-Info "If some services are still unhealthy, wait 2-3 minutes and run the health check again"
Write-Host "Services may take time to fully initialize and pass health checks" -ForegroundColor Yellow