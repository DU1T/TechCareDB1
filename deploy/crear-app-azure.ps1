# Crea (una sola vez) el App Service donde vive TechCare: API + web en una sola URL.
# Requisitos: az login hecho y la base TechCare ya creada en el servidor SQL de Azure.
#   ./crear-app-azure.ps1                       -> usa los nombres por defecto de abajo
#   ./crear-app-azure.ps1 -App techcare-otro    -> si el nombre ya está ocupado en Azure
# Se puede volver a ejecutar: lo que ya existe no se duplica y la clave JWT no se cambia.
# Pide la contraseña de techcare_app al ejecutarse: nunca queda en el repo ni en la pantalla.
# Después de esto: ./publicar.ps1 -Azure
param(
    [string]$Grupo       = 'rg-techcare',
    [string]$ServidorSql = 'techcare-grupo-bhl',
    [string]$Base        = 'TechCare',
    [string]$Plan        = 'plan-techcare',
    [string]$App         = 'techcare-api-grupo-bhl'
)
$ErrorActionPreference = 'Stop'
function Paso([string]$texto) { Write-Host ">> $texto" -ForegroundColor Cyan }
function Az { & az @args; if ($LASTEXITCODE) { throw "Falló: az $($args -join ' ')" } }

Paso 'Comprobando la sesión de Azure'
$cuenta = az account show --query name -o tsv
if ($LASTEXITCODE) { throw 'No hay sesión: ejecute az login primero.' }
Write-Host "   Suscripción: $cuenta"

Paso "Leyendo la región del servidor SQL $ServidorSql"
$region = Az sql server show -g $Grupo -n $ServidorSql --query location -o tsv
Write-Host "   Región: $region (la API va en la misma, para que la base responda rápido)"

Paso "Plan gratuito F1 Linux ($Plan)"
az appservice plan show -g $Grupo -n $Plan -o none 2>$null
if ($LASTEXITCODE) { Az appservice plan create -g $Grupo -n $Plan --sku F1 --is-linux --location $region -o none }
else { Write-Host '   Ya existe.' }

Paso "Aplicación web $App (.NET 8)"
az webapp show -g $Grupo -n $App -o none 2>$null
if ($LASTEXITCODE) { Az webapp create -g $Grupo -p $Plan -n $App --runtime 'DOTNETCORE:8.0' -o none }
else { Write-Host '   Ya existe.' }
Az webapp update -g $Grupo -n $App --https-only true -o none

Paso 'Configuración (equivale a user-secrets: ASP.NET la lee como Jwt:Key, etc.)'
$actuales = Az webapp config appsettings list -g $Grupo -n $App --query '[].name' -o tsv
$ajustes = @('ASPNETCORE_ENVIRONMENT=Production', 'Jwt__Issuer=techcare-api', 'Jwt__Audience=techcare-web')
if ($actuales -notcontains 'Jwt__Key') {
    # 64 bytes aleatorios: la API exige al menos 64. Si ya existe no se cambia (cerraría todas las sesiones).
    $bytes = [byte[]]::new(64); [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $ajustes += "Jwt__Key=$([Convert]::ToBase64String($bytes))"
}
Az webapp config appsettings set -g $Grupo -n $App --settings @ajustes -o none

Paso 'Cadena de conexión con techcare_app (mínimo privilegio)'
$sec   = Read-Host 'Contraseña de techcare_app' -AsSecureString
$clave = [System.Net.NetworkCredential]::new('', $sec).Password
$cadena = "Server=tcp:$ServidorSql.database.windows.net,1433;Initial Catalog=$Base;User ID=techcare_app;Password=$clave;" +
          'Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;'
# Se pasa por archivo (@archivo): az.cmd rompe contraseñas con & ^ % si van como argumento
$tmp = New-TemporaryFile
try {
    Set-Content -Path $tmp -Value "TechCare=$cadena" -NoNewline -Encoding utf8NoBOM
    Az webapp config connection-string set -g $Grupo -n $App -t SQLAzure --settings "@$tmp" -o none
} finally {
    Remove-Item $tmp -Force
    $clave = $null; $cadena = $null
}

Paso 'Firewall del servidor SQL: solo las IP de salida de la API'
$ips = (Az webapp show -g $Grupo -n $App --query possibleOutboundIpAddresses -o tsv).Split(',') | Sort-Object -Unique
$i = 0
foreach ($ip in $ips) {
    $i++
    Az sql server firewall-rule create -g $Grupo -s $ServidorSql -n "app-$App-$i" --start-ip-address $ip --end-ip-address $ip -o none
}
Write-Host "   $i reglas (una por IP de salida)."

Write-Host "Listo: https://$App.azurewebsites.net  ->  ahora ejecute ./publicar.ps1 -Azure" -ForegroundColor Green
