# Reconstruye una base TechCare desde cero en un solo paso:
#   build -> master -> datos de prueba -> seguridad -> auditoría DDL
# Uso (PowerShell 7, desde la carpeta database):
#   ./reconstruir.ps1 -Servidor localhost -Integrada -Base TechCare_Infra     # local con autenticación de Windows
#   ./reconstruir.ps1 -Servidor tcp:SERVIDOR.database.windows.net,1433 -Usuario tcadmin -Azure   # compartida (SOLO C)
#   ./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_back -Base TechCare_Back            # VM (plan B)
#   ./reconstruir.ps1 ... -SinDatos        # solo estructura
# Nota: el parámetro se llama -Base (no -Db) porque -Db choca con el alias de -Debug en PowerShell.
param(
    [Parameter(Mandatory)][string]$Servidor,
    [string]$Usuario,
    [switch]$Integrada,
    [string]$Base = 'TechCare',
    [switch]$Azure,
    [switch]$SinDatos
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if ($Base -eq 'TechCare') {
    $ok = Read-Host "Esto BORRA y recrea la base COMPARTIDA '$Base'. ¿Ya avisó al equipo? Escriba SI"
    if ($ok -ne 'SI') { Write-Host 'Cancelado.'; return }
}
if (-not $Integrada -and -not $Usuario) { throw 'Indique -Usuario (autenticación SQL) o -Integrada (Windows).' }
if (-not $Integrada) {
    $sec   = Read-Host "Contraseña de $Usuario" -AsSecureString
    $clave = [System.Net.NetworkCredential]::new('', $sec).Password
}

# sqlcmd: se prefiere el clásico (ODBC), que acepta -f 65001. El nuevo (go-sqlcmd)
# no acepta -f, pero ya lee UTF-8 por defecto, así que con él se omite.
$sqlcmd = (Get-Command sqlcmd -All -CommandType Application -ErrorAction SilentlyContinue |
           Where-Object { $_.Source -match '\\ODBC\\' } | Select-Object -First 1).Source
$usaF = [bool]$sqlcmd
if (-not $sqlcmd) { $sqlcmd = (Get-Command sqlcmd -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source }
Write-Host "sqlcmd: $sqlcmd" -ForegroundColor DarkGray

function Invoke-Sql([string]$archivo, [string]$bd) {
    $a = @('-S', $Servidor, '-b', '-I', '-i', $archivo)    # -I: QUOTED_IDENTIFIER ON (el sqlcmd clásico lo deja en OFF)
    if ($usaF) { $a += @('-f', '65001') }
    if ($Integrada) { $a += '-E' } else { $a += @('-U', $Usuario, '-P', $clave) }
    if (-not $Azure) { $a += '-C' }            # local/VM: certificado autofirmado
    if ($bd)         { $a += @('-d', $bd) }
    Write-Host ">> $(Split-Path $archivo -Leaf)" -ForegroundColor Cyan
    & $sqlcmd @a
    if ($LASTEXITCODE -ne 0) { throw "Falló $(Split-Path $archivo -Leaf) (código $LASTEXITCODE). Nada después de este archivo se ejecutó." }
}

& (Join-Path $root 'build_master.ps1') -Db $Base -Azure:$Azure
$prefijo = if ($Azure) { "${Base}_Azure" } else { $Base }
$build   = Join-Path $root 'build'

if ($Azure) {
    Invoke-Sql (Join-Path $root 'limpiar_base.sql') $Base          # Azure no permite DROP DATABASE desde el script
    Invoke-Sql (Join-Path $build "${prefijo}_Master.sql") $Base
} else {
    Invoke-Sql (Join-Path $build "${prefijo}_Master.sql") $null    # 01 hace DROP/CREATE DATABASE y USE
}
if (-not $SinDatos) { Invoke-Sql (Join-Path $build "${prefijo}_DatosPrueba.sql") $Base }

if ($Azure)                   { Invoke-Sql (Join-Path $root '91_seguridad_azure.sql') $Base }
elseif ($Base -eq 'TechCare') { Invoke-Sql (Join-Path $root '90_seguridad.sql') $null }
Invoke-Sql (Join-Path $root '92_auditoria_ddl.sql') $Base

Write-Host "Listo: $Base reconstruida en $Servidor" -ForegroundColor Green
