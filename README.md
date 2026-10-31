# TechCare Solutions

Sistema de gestión de un taller de reparación de equipos: órdenes de servicio, diagnóstico y reparación, inventario por bodega con kárdex, compras a proveedores, facturación, pagos y entrega. Proyecto del curso Bases de Datos (UMG).

**Versión pública:** https://techcare-api-grupo-bhl.azurewebsites.net (la primera carga puede tardar hasta un minuto: la base y el servidor se despiertan).

```text
Navegador ──► API .NET 8 (/api) ──► SQL Server
  (Nuxt 4)      JWT + Dapper         procedimientos almacenados, vistas, triggers
```

La web nunca habla con SQL Server: todo pasa por la API, y la API escribe solo con procedimientos almacenados. Las reglas del negocio (existencias, estados de la orden, saldos) viven en la base.

## Requisitos

| Herramienta | Versión | Para qué |
| --- | --- | --- |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | cualquiera reciente | SQL Server 2022 en un contenedor. También sirve un SQL Server 2022 instalado (Developer o Express). |
| [sqlcmd](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility) | cualquiera | ejecutar los scripts de la base |
| [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`) | 7.4 o superior | los scripts `.ps1` (en macOS/Linux hay versión `.sh` para la base) |
| [.NET SDK](https://dotnet.microsoft.com/download/dotnet/8.0) | 8 | la API |
| [Node.js](https://nodejs.org/) | 22.22.3 o superior (o 24.15+) | la web |
| Git | cualquiera | clonar el repositorio |

Todos los comandos de abajo son para **PowerShell 7**, empezando en la carpeta del repositorio:

```powershell
git clone https://github.com/DU1T/TechCareDB1.git techcare
cd techcare
```

## 1. Base de datos

**1.1 SQL Server en Docker** (si ya tienes SQL Server instalado, salta al 1.2). Elige una contraseña para `sa` con mayúsculas, minúsculas, números y símbolos; se usa en los pasos siguientes en lugar de `<CLAVE_SA>`.

```powershell
docker run -d --name techcare-sql -p 1433:1433 `
  -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD="<CLAVE_SA>" -e MSSQL_COLLATION=Modern_Spanish_CI_AS `
  mcr.microsoft.com/mssql/server:2022-latest
```

Espera unos 20 segundos a que arranque (`docker logs techcare-sql` muestra *SQL Server is now ready*).

**1.2 Crear la base con sus datos de prueba** (estructura, procedimientos, vistas, triggers, reportes y datos; tarda menos de un minuto). Pide la contraseña de `sa`:

```powershell
cd database
./reconstruir.ps1 -Servidor "localhost,1433" -Usuario sa -Base TechCare_Local
cd ..
```

Con SQL Server instalado y autenticación de Windows: `./reconstruir.ps1 -Servidor localhost -Integrada -Base TechCare_Local`.
Al final debe decir **`Listo: TechCare_Local reconstruida`**, y las tablas de verificación de los datos deben salir en `OK`.

> El servidor va entre comillas: sin ellas, PowerShell lee la coma como una lista.
> Más opciones (generar solo los scripts, desplegar un archivo, macOS/Linux): [`database/README.md`](database/README.md).

## 2. API (.NET 8)

La configuración secreta va en `user-secrets` (se guarda en tu usuario de Windows, nunca en el repositorio):

```powershell
cd backend/TechCare.Api
dotnet user-secrets set "ConnectionStrings:TechCare" "Server=localhost,1433;Database=TechCare_Local;User Id=sa;Password=<CLAVE_SA>;TrustServerCertificate=True"
dotnet user-secrets set "Jwt:Key" ([Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48)))
dotnet run --launch-profile http
```

Con autenticación de Windows, la cadena es `Server=localhost;Database=TechCare_Local;Integrated Security=True;TrustServerCertificate=True`.
`Jwt:Key` es la clave con la que la API firma las sesiones: el comando genera una aleatoria de 64 caracteres (el mínimo que exige la API).

La API queda en **http://localhost:5080**. Para comprobarla, abre http://localhost:5080/swagger. Deja esta ventana abierta.

## 3. Web (Nuxt 4)

En **otra** ventana de PowerShell, desde la carpeta del repositorio:

```powershell
cd frontend
npm ci
@"
NUXT_PUBLIC_API_BASE=http://localhost:5080/api
NUXT_PUBLIC_MODO_SIMULADO=false
"@ | Set-Content .env
npm run dev
```

Abre **http://localhost:3000** e inicia sesión con un usuario de prueba (abajo). Con la API real, arriba a la derecha **no** debe aparecer la etiqueta *API simulada*.

Si en cambio copias el ejemplo tal cual (`Copy-Item .env.example .env`), la web usa una API simulada con datos falsos, útil para trabajar en pantallas sin base de datos; arriba a la derecha aparece **API simulada**. Detalles en [`frontend/README.md`](frontend/README.md).

## Opción: todo en una sola dirección

Así se publica en Azure y así se hace la demo en red local: la API sirve también la web, sin `npm run dev` ni CORS. Con los `user-secrets` del paso 2 ya configurados:

```powershell
./deploy/publicar.ps1                     # compila la web y la API en backend/TechCare.Api/publish
cd backend/TechCare.Api/publish
$env:ASPNETCORE_ENVIRONMENT = "Development"   # para que lea los user-secrets
dotnet TechCare.Api.dll --urls http://localhost:5080
```

Abre **http://localhost:5080**.

## Usuarios de prueba

Contraseña de todos: **`Demo2026!`** (son datos de prueba).

| Usuario | Rol | Qué puede hacer |
| --- | --- | --- |
| `recepcion1`, `recepcion2` | Recepción | clientes, recibir equipos, crear órdenes, entregar |
| `tecnico1`, `tecnico2` | Técnico | diagnosticar, reparar, usar repuestos |
| `bodega1`, `bodega2` | Bodega | inventario, kárdex, ajustes, compras y recepción de compras |
| `caja1`, `caja2` | Caja | facturar, cobrar y entregar |
| `administrador1`, `administrador2` | Administrador | todo |

## Pruebas de la base

En [`database/pruebas/`](database/pruebas/) hay un script por prueba del plan. Se ejecutan sobre la base creada en el paso 1 (con `sqlcmd ... -d TechCare_Local -i <archivo>`, o en SSMS/DBeaver) y cada uno imprime `OK` o `FALLA` por comprobación:

| Script | Qué prueba | ¿Deja cambios? |
| --- | --- | --- |
| `T03_flujo_reparacion.sql` | flujo de una orden hecha desde Swagger (diagnóstico, autorización y reparación) | no; trae `USE TechCare_Back` (base personal de B) |
| `T04_T05_consumo_repuesto.sql` | consumir repuestos: rechazos y consumo válido con precio histórico | no |
| `T06_compra_recepcion.sql` | registrar y recibir una compra | no |
| `T07_rollback.sql` | error a mitad de una transacción (con y sin `XACT_ABORT`) | no |
| `T08_T10_facturacion.sql` | facturar, pagar, anular pago y entregar | sí (solo en una base personal) |
| `T11_historial_equipo.sql` | historial técnico de un equipo | no |
| `T12_reportes_facturacion.sql` | reportes 10, 11 y 12 | no |
| `T13_estado_stock.sql` | estado del stock por bodega y dashboard | no |
| `T14_precio_historico.sql` | cambiar un precio no altera facturas viejas; queda auditado | no |
| `R14_kardex_inmutable.sql` | el kárdex no se edita ni se borra | no |
| `R16_integridad_directa.sql` | las restricciones rechazan datos inválidos escritos directo en SQL | no |
| `verificar_reportes_5_1.sql` | los 12 reportes cumplen la sección 5.1 del enunciado (tablas, `LEFT JOIN`, sin `SELECT *`/`DISTINCT`); solo lee | no |

Los que dicen "no" terminan en `ROLLBACK` o solo leen: se pueden repetir las veces que quieras.

## Prueba de punta a punta por la API

[`backend/pruebas/prueba_api_e2e.py`](backend/pruebas/prueba_api_e2e.py) usa el sistema como lo haría la aplicación: entra con los 5 roles y recorre el ciclo completo de una orden (cliente, equipo, orden, diagnóstico, reparación con repuestos, factura, pagos y entrega), las compras, los usuarios, los catálogos, el dashboard y los 12 reportes, incluidos los rechazos. Con la API corriendo sobre una **base de prueba** (crea datos), no sobre la compartida:

```powershell
python backend/pruebas/prueba_api_e2e.py http://localhost:5080
```

Debe terminar con `RESULTADO: 109 OK, 0 FALLA`. El plan completo, con resultado esperado y obtenido, está en [`docs/PLAN_PRUEBAS.md`](docs/PLAN_PRUEBAS.md).

## Estructura del repositorio

```text
database/   scripts numerados de la base (01 tablas … 92 auditoría), datos de prueba, reconstruir.ps1 y pruebas/
backend/    API .NET 8 (TechCare.Api): controladores, acceso a datos con Dapper, JWT; pruebas/ (prueba de punta a punta)
frontend/   web Nuxt 4 + Nuxt UI
deploy/     publicar.ps1 (una sola URL; -Azure la sube) y crear-app-azure.ps1
docs/       diagrama ER, normalización, casos de prueba y guías del equipo
```

Documentos del modelo:

- Diagrama entidad-relación: [`docs/ER_TechCare.png`](docs/ER_TechCare.png) ([PDF](docs/ER_TechCare.pdf)).
- Normalización (1FN, 2FN, 3FN, FNBC y datos repetidos a propósito): [`docs/normalizacion.md`](docs/normalizacion.md).

## Problemas comunes

| Síntoma | Causa y solución |
| --- | --- |
| `reconstruir.ps1` falla con *Login failed for user 'sa'* | Contraseña distinta a la del `docker run`, o el contenedor aún no termina de arrancar: espera y repite. |
| La API se cierra con *No se configuró Jwt:Key* o *al menos 64 bytes* | Falta el segundo `user-secrets set` del paso 2, o se ejecutó en otra carpeta: deben correrse dentro de `backend/TechCare.Api`. |
| La API no arranca: *framework 'Microsoft.AspNetCore.App', version '8.0.0' was not found* | Falta el runtime de .NET 8: instala el SDK 8. Si solo tienes uno más nuevo, `$env:DOTNET_ROLL_FORWARD = "Major"` antes de `dotnet run`. |
| El login dice *Ocurrió un error inesperado* | La API no está corriendo, o el `.env` de la web no apunta a `http://localhost:5080/api` (reinicia `npm run dev` después de cambiarlo). |
| Con la API real aparece la etiqueta *API simulada* (y los atajos de rol en el login) | En desarrollo la web activa el modo simulado si no se apaga: falta `NUXT_PUBLIC_MODO_SIMULADO=false` en `.env` (paso 3). Reinicia `npm run dev`. |
| La primera carga en Azure tarda casi un minuto | Normal: la base serverless y el plan gratuito se duermen. Espera y recarga. |
