# Crea UNA vez los usuarios de la base compartida en Azure, con contraseñas
# fuertes generadas aquí, y aplica los permisos (91_seguridad_azure.sql).
# Guarda las contraseñas en ..\infra\credenciales_azure.txt (infra/ está en .gitignore).
# Uso (PowerShell 7, desde la carpeta database):
#   ./crear_usuarios_azure.ps1 -Servidor tcp:techcare-grupo5.database.windows.net,1433
# Nota: el parámetro se llama -Base (no -Db) porque -Db choca con el alias de -Debug en PowerShell.
param(
    [Parameter(Mandatory)][string]$Servidor,
    [string]$Admin = 'tcadmin',
    [string]$Base = 'TechCare'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Nueva-Clave {
    # Sin ; ' " ni espacios para que no rompan cadenas de conexión ni sqlcmd
    $c = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!#%+=?'
    $txt = -join (1..20 | ForEach-Object { $c[(Get-Random -Maximum $c.Length)] })
    return $txt + 'Aa9!'   # garantiza mayúscula, minúscula, dígito y símbolo
}

$sec   = Read-Host "Contraseña de $Admin" -AsSecureString
$clave = [System.Net.NetworkCredential]::new('', $sec).Password

$claves = [ordered]@{
    CLAVE_APP   = Nueva-Clave
    CLAVE_FRONT = Nueva-Clave
    CLAVE_BACK  = Nueva-Clave
    CLAVE_INFRA = Nueva-Clave
}

$vars = @()
foreach ($k in $claves.Keys) { $vars += @('-v', "$k=$($claves[$k])") }

# sqlcmd: se prefiere el clásico (ODBC), que acepta -f 65001; go-sqlcmd no lo acepta y ya lee UTF-8.
$sqlcmd = (Get-Command sqlcmd -All -CommandType Application -ErrorAction SilentlyContinue |
           Where-Object { $_.Source -match '\\ODBC\\' } | Select-Object -First 1).Source
$cp = @('-f', '65001')
if (-not $sqlcmd) { $sqlcmd = (Get-Command sqlcmd -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source; $cp = @() }

Write-Host ">> crear_usuarios_azure.sql" -ForegroundColor Cyan
& $sqlcmd -S $Servidor -d $Base -U $Admin -P $clave -b -I @cp -i (Join-Path $root 'crear_usuarios_azure.sql') @vars
if ($LASTEXITCODE -ne 0) { throw 'Falló la creación de usuarios.' }

Write-Host ">> 91_seguridad_azure.sql" -ForegroundColor Cyan
& $sqlcmd -S $Servidor -d $Base -U $Admin -P $clave -b -I @cp -i (Join-Path $root '91_seguridad_azure.sql')
if ($LASTEXITCODE -ne 0) { throw 'Falló la aplicación de permisos.' }

$infra = Join-Path (Split-Path $root -Parent) 'infra'
New-Item -ItemType Directory -Force -Path $infra | Out-Null
$archivo = Join-Path $infra 'credenciales_azure.txt'
$srv = $Servidor -replace '^tcp:', ''
@"
Credenciales de la base compartida $Base en $srv
Generadas el $(Get-Date -Format 'yyyy-MM-dd HH:mm'). NO subir a git. Entregar a cada uno por mensaje directo.

techcare_app (backend)  : $($claves.CLAVE_APP)
dev_front    (A)        : $($claves.CLAVE_FRONT)
dev_back     (B)        : $($claves.CLAVE_BACK)
dev_infra    (C)        : $($claves.CLAVE_INFRA)

Cadena del backend:
Server=$Servidor;Database=$Base;User Id=techcare_app;Password=$($claves.CLAVE_APP);Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;

Si un usuario ya existía, su contraseña NO cambió: la de arriba no aplica para él.
"@ | Set-Content -Path $archivo -Encoding utf8

Write-Host "Listo. Contraseñas guardadas en $archivo" -ForegroundColor Green
