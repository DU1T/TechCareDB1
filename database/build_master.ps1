# Une los scripts numerados en los entregables (equivalente a build_master.sh).
#   pwsh ./build_master.ps1                    -> build/TechCare_Master.sql + build/TechCare_DatosPrueba.sql
#   pwsh ./build_master.ps1 -Db TechCare_Ana   -> base personal
#   pwsh ./build_master.ps1 -Azure             -> variante Azure (sin 01 ni USE)
param([string]$Db = 'TechCare', [switch]$Azure)
$ErrorActionPreference = 'Stop'
if ($Db -notmatch '^[A-Za-z][A-Za-z0-9_]*$') { throw "Nombre de BD inválido: $Db" }
$root  = $PSScriptRoot
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$prefix = if ($Azure) { "${Db}_Azure" } else { $Db }

function Convert-Script([string]$text) {
    if ($Azure) {
        return ($text -replace '(?m)^\s*USE\s+[A-Za-z_]+\s*;?\s*$', '')
    }
    $text = $text -replace '\bUSE TechCare;', "USE $Db;"
    $text = $text -replace "N'TechCare'", "N'$Db'"
    return ($text -replace '\b(ALTER|DROP|CREATE) DATABASE TechCare\b', "`$1 DATABASE $Db")
}

function Join-Scripts($files, $out) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("/* Generado por build_master.ps1 el $(Get-Date -Format 'yyyy-MM-dd HH:mm') | BD=$Db | azure=$Azure - NO EDITAR A MANO */")
    foreach ($f in $files) {
        [void]$sb.AppendLine("`r`n/* ################ $($f.Name) ################ */")
        [void]$sb.AppendLine((Convert-Script (Get-Content $f.FullName -Raw -Encoding UTF8)))
        [void]$sb.AppendLine("GO")
    }
    [System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.UTF8Encoding]::new($true))
    Write-Host "OK -> $out ($($files.Count) archivos)"
}

$all = Get-ChildItem $root -Filter '*.sql' | Where-Object { $_.Name -match '^\d{2}_' } | Sort-Object Name
if ($Azure) { $all = $all | Where-Object { [int]$_.Name.Substring(0,2) -ne 1 } }
Join-Scripts ($all | Where-Object { [int]$_.Name.Substring(0,2) -lt 80 }) (Join-Path $build "${prefix}_Master.sql")
Join-Scripts ($all | Where-Object { $n = [int]$_.Name.Substring(0,2); $n -ge 80 -and $n -lt 90 }) (Join-Path $build "${prefix}_DatosPrueba.sql")
# Seguridad aparte: 90_seguridad.sql (VM/local) o 91_seguridad_azure.sql (Azure).
