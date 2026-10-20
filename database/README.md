# TechCare — Base de datos

## Reconstruir una base en un paso
```powershell
./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_back -Db TechCare_Back     # su base personal
./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_infra                      # compartida: SOLO C, avisando antes
./reconstruir.ps1 -Servidor tcp:SERVIDOR.database.windows.net,1433 -Usuario techcare_admin -Azure
```
macOS/Linux: `./reconstruir.sh -s vm-techcare,1433 -u dev_front -d TechCare_Front` (agregar `--azure` para Azure).

Hace: build → master → datos de prueba → seguridad (solo compartida/Azure) → auditoría DDL.
Local con autenticación de Windows: `./reconstruir.ps1 -Servidor localhost -Integrada -Db TechCare_Back`.
Usuarios de Azure (una sola vez): `./crear_usuarios_azure.ps1 -Servidor tcp:SERVIDOR.database.windows.net,1433`.

## Desplegar solo su archivo (SP, vistas, funciones, triggers)
```powershell
sqlcmd -S vm-techcare,1433 -U dev_back -P '***' -C -b -f 65001 -d TechCare_Back -i 41_sp_ordenes.sql
```
Azure: quitar `-C` y usar `-S tcp:SERVIDOR.database.windows.net,1433`.
`-b` detiene al primer error · `-f 65001` lee UTF-8 (tildes) · `-C` confía en el certificado del servidor · `-d` base destino.

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
