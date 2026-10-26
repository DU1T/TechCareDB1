# Publica TechCare en una sola URL: la API .NET sirve también la web de Nuxt.
#   ./publicar.ps1                      -> compila web + API en backend/TechCare.Api/publish (para probar en local o en la demo LAN)
#   ./publicar.ps1 -Azure               -> además la sube al App Service (requiere az login)
#   ./publicar.ps1 -Azure -App techcare-api-otro -Grupo rg-otro
# La configuración secreta (cadena de conexión, Jwt:Key) NO va aquí: vive en el App Service
# (az webapp config appsettings / connection-string) o en user-secrets en local.
param(
    [switch]$Azure,
    [string]$App   = 'techcare-api-grupo-bhl',
    [string]$Grupo = 'rg-techcare'
)
$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$front   = Join-Path $repo 'frontend'
$api     = Join-Path $repo 'backend\TechCare.Api'
$wwwroot = Join-Path $api 'wwwroot'
$publish = Join-Path $api 'publish'

function Paso([string]$texto) { Write-Host ">> $texto" -ForegroundColor Cyan }

# 1. Web: SPA estática que llama a la API por ruta relativa (/api), así funciona en cualquier host
Paso 'Compilando la web (nuxi generate con NUXT_PUBLIC_API_BASE=/api)'
Push-Location $front
try {
    if (-not (Test-Path 'node_modules')) { npm ci; if ($LASTEXITCODE) { throw 'npm ci falló' } }
    $env:NUXT_PUBLIC_API_BASE = '/api'
    $env:NUXT_PUBLIC_MODO_SIMULADO = 'false'
    npx nuxi generate
    if ($LASTEXITCODE) { throw 'nuxi generate falló' }
} finally {
    Remove-Item Env:NUXT_PUBLIC_API_BASE, Env:NUXT_PUBLIC_MODO_SIMULADO -ErrorAction SilentlyContinue
    Pop-Location
}

# 2. Copiar la web a wwwroot (se borra la anterior para no dejar archivos viejos)
Paso 'Copiando la web a backend/TechCare.Api/wwwroot'
if (Test-Path $wwwroot) { Remove-Item -Recurse -Force $wwwroot }
Copy-Item -Recurse (Join-Path $front '.output\public') $wwwroot

# 3. API en modo Release (incluye wwwroot)
Paso 'Publicando la API (dotnet publish -c Release)'
if (Test-Path $publish) { Remove-Item -Recurse -Force $publish }
dotnet publish $api -c Release -o $publish --nologo
if ($LASTEXITCODE) { throw 'dotnet publish falló' }

if (-not $Azure) {
    Write-Host "Listo: $publish" -ForegroundColor Green
    Write-Host 'Para probar en local: cd backend/TechCare.Api/publish; dotnet TechCare.Api.dll --urls http://localhost:5080'
    return
}

# 4. Subir al App Service
Paso "Subiendo a Azure ($Grupo / $App)"
$zip = Join-Path $api 'api.zip'
Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $zip -Force
az webapp deploy -g $Grupo -n $App --src-path $zip --type zip
if ($LASTEXITCODE) { throw 'az webapp deploy falló' }
Remove-Item $zip
Write-Host "Listo: https://$App.azurewebsites.net (la primera carga tarda: el plan F1 y la base se despiertan)" -ForegroundColor Green
