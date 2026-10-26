# TechCare — Base de datos

## Reconstruir una base en un paso
```powershell
./reconstruir.ps1 -Servidor localhost -Integrada -Base TechCare_Back                      # A y B (Windows)
./reconstruir.ps1 -Servidor "localhost,1434" -Usuario sa -Base TechCare_Infra            # C (Docker)
./reconstruir.ps1 -Servidor "tcp:techcare-grupo-bhl.database.windows.net,1433" -Usuario tcadmin -Azure   # compartida: SOLO C, avisando antes
```
macOS/Linux: `./reconstruir.sh -s "localhost,1434" -u sa -d TechCare_Infra` (agregar `--azure` para Azure).

Hace: build → master → datos de prueba → seguridad (solo compartida/Azure) → auditoría DDL.
El parámetro es `-Base`, no `-Db`: `-Db` choca con el alias de `-Debug` en PowerShell.
Usuarios de Azure (una sola vez): `./crear_usuarios_azure.ps1 -Servidor tcp:techcare-grupo-bhl.database.windows.net,1433`.

## Desplegar solo su archivo (SP, vistas, funciones, triggers)
```powershell
sqlcmd -S localhost -E -C -b -I -f 65001 -d TechCare_Back -i 41_sp_ordenes.sql                                      # local
sqlcmd -S tcp:techcare-grupo-bhl.database.windows.net,1433 -U dev_back -b -I -f 65001 -d TechCare -i 41_sp_ordenes.sql  # Azure, desde master
```
`-b` detiene al primer error · `-I` activa `QUOTED_IDENTIFIER` (sin él fallan los índices filtrados) · `-f 65001` lee UTF-8 (tildes) · `-C` confía en el certificado del servidor local (en Azure no va) · `-d` base destino.
Con el sqlcmd nuevo (go-sqlcmd) se omite `-f 65001`: ya lee UTF-8.

## Solo generar los entregables
```bash
./build_master.sh                    # build/TechCare_Master.sql + build/TechCare_DatosPrueba.sql
./build_master.sh --db TechCare_Ana  # variante para una base personal
./build_master.sh --azure            # variante Azure (sin 01 ni USE)
```
Windows: `./build_master.ps1 [-Db TechCare_Ana] [-Azure]`.

## Archivos y dueños
| Archivo | Contenido | Dueño |
|---|---|---|
| 01–05, 10, 30, 40 | Base, tablas, índices, tipo TVP, catálogos, funciones, trigger de estados, SP comunes | NÚCLEO (congelado; cambios solo por PR aprobado por los 3) |
| 20 / 41 / 50 / 80 / 83 | Vistas, SP, reportes y datos de órdenes, diagnóstico y reparación | B · Backend |
| 21 / 31 / 42 / 51 / 81 / 82 / 85 | Inventario, compras, triggers de auditoría, reportes, datos maestros, compras y escenarios | C · Fullstack/Infra |
| 22 / 43 / 52 / 84 | Facturación, pagos, entrega, trazabilidad, datos de facturación | A · Frontend |
| 90 / 91 / 92 / limpiar_base / crear_usuarios_azure.* | Seguridad local, roles y permisos de Azure, auditoría y protección DDL, limpieza, creación única de usuarios Azure | C · Fullstack/Infra |

## Reglas
- Vistas, funciones, SP y triggers siempre con `CREATE OR ALTER` (se pueden re-ejecutar).
- Nada se crea "a mano" en SSMS sin que esté en su archivo y en git.
- Códigos THROW: 500xx núcleo · 501xx inventario · 502xx órdenes · 503xx facturación · 510xx triggers.
- SP de proceso devuelven el id creado en un SELECT final; en los scripts de datos se recupera por la llave de negocio.
- `build/` no se edita ni se sube a git: se regenera.
