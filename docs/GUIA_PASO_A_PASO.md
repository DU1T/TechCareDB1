# TechCare — Guía paso a paso del equipo

> Complemento del documento *Plan de acción del proyecto final* (pestañas *Plan general*, *Guía A*, *Guía B*, *Guía C*). Esta guía reúne todo en un solo archivo, con más detalle y con los comandos exactos. Si algo de aquí no coincide con el plan, avisen: deben decir lo mismo.
>
> Entrega: **viernes 30 de octubre de 2026**.
>
> **Actualización del 19 de octubre:** la infraestructura definitiva está en `GUIA_FINAL_C_INFRA.md` y manda sobre esta guía donde no coincidan. Cambios principales: la base compartida `TechCare` vive en **Azure SQL Database**; las bases personales viven **en la laptop de cada uno** (SQL Server 2022 Developer, `./reconstruir.ps1 -Servidor localhost -Integrada -Db TechCare_<suyo>`); los usuarios de Azure se crean con `crear_usuarios_azure.ps1` y los desarrolladores no pueden cambiar tablas (error 51090); la VM + Tailscale queda como plan B.

| Letra | Rol | Dominio de base de datos | Nombre |
|---|---|---|---|
| **A** | Frontend | Facturación, pagos, entrega y trazabilidad | ___________ |
| **B** | Backend | Órdenes, diagnóstico y reparación | ___________ |
| **C** | Fullstack / Infra | Inventario, compras, auditoría e infraestructura | ___________ |

Cada dominio ya trae **un procedimiento modelo escrito** en su archivo: C tiene `sp_UtilizarRepuesto` y `sp_RecibirCompra`; B tiene `sp_RegistrarOrdenServicio`; A tiene `sp_RegistrarPago`. Cada integrante copia ese patrón en los demás SP de su dominio y los defiende como propios. **Ninguno se ha ejecutado todavía contra un SQL Server real.** La primera construcción de C (sección 4, C1) y el check automático `db-build` de GitHub (sección 2.8) son los que los validan.

## Índice

0. [Calendario resumido](#0-calendario-resumido)
1. [Día 0: lo que hacen los 3](#1-día-0-lo-que-hacen-los-3)
2. [Cómo trabajamos los 3 en la misma base de datos](#2-cómo-trabajamos-los-3-en-la-misma-base-de-datos)
3. [Opción Azure SQL Database, paso a paso](#3-opción-azure-sql-database-paso-a-paso)
4. [Paso a paso de C · Fullstack / Infra](#4-paso-a-paso-de-c--fullstack--infra)
5. [Paso a paso de B · Backend](#5-paso-a-paso-de-b--backend)
6. [Paso a paso de A · Frontend](#6-paso-a-paso-de-a--frontend)
7. [Cierre común: 27, 28, 29 y 30 de octubre](#7-cierre-común-27-28-29-y-30-de-octubre)

---

## 0. Calendario resumido

| Fase | Fechas | Hito al final |
|---|---|---|
| 0 · Arranque | lun 19 | 18:00: los 3 se conectan a `TechCare`. 20:00: revisión del núcleo. 22:00: núcleo **congelado** |
| 1 · Órdenes y compras | mar 20 – mié 21 | Contrato de la API en Swagger (mar 20). Crear y diagnosticar una orden desde la app (T01–T03); recibir una compra (T06) |
| 2 · Procesos críticos | jue 22 – vie 23 | Reparación, consumo de repuestos, factura y pago con rollback demostrable (T04–T10) |
| 3 · Integración | sáb 24 – dom 25 | Flujo completo de punta a punta con datos de prueba; backend con el usuario `techcare_app` |
| 4 · Reportes y modelo | lun 26 | 12 reportes funcionando en la app; diagrama ER y normalización listos; no se tocan más tablas |
| 5 · Cierre | mar 27 – vie 30 | Prueba en limpio, documentos, ensayo de defensa, entrega |

El domingo 25 es la holgura del calendario: úsenla solo si van atrasados.

Convenciones de esta guía:

- `<SERVIDOR>` = `vm-techcare,1433` (opción VM + Tailscale) o `tcp:techcare-grupo5.database.windows.net,1433` (opción Azure; cambien `grupo5` por el nombre real).
- `***` = contraseña. Nunca se escribe en archivos que van a git.
- Los comandos están en **PowerShell 7** (Windows). En `database/` hay equivalentes `.sh` para macOS.
- `[ ]` = tarea para marcar al terminarla.

---

## 1. Día 0: lo que hacen los 3

Tiempo estimado: 1.5 a 2 horas por persona. **C empieza primero** (servidor y repositorio, sección 4, C1 y C2); mientras tanto, A y B instalan herramientas.

### 1.1 Instalar herramientas

| Herramienta | Para qué | A | B | C | Instalación en Windows |
|---|---|:-:|:-:|:-:|---|
| Git | Repositorio | ✔ | ✔ | ✔ | `winget install Git.Git` |
| PowerShell 7 | Scripts de build y reconstrucción | ✔ | ✔ | ✔ | `winget install Microsoft.PowerShell` |
| sqlcmd (go-sqlcmd) | Ejecutar scripts desde la terminal | ✔ | ✔ | ✔ | `winget install sqlcmd` (macOS: `brew install sqlcmd`) |
| SSMS 21 | Editor y explorador de SQL Server (solo Windows) | ✔ | ✔ | ✔ | Instalador de Microsoft |
| VS Code + extensión **SQL Server (mssql)** | Alternativa a SSMS; única opción en macOS | opc. | opc. | opc. | `winget install Microsoft.VisualStudioCode` |
| .NET 8 SDK | Backend | opc. | ✔ | ✔ | `winget install Microsoft.DotNet.SDK.8` (macOS: `brew install --cask dotnet-sdk@8`) |
| Visual Studio 2022 Community, Rider o VS Code + C# Dev Kit | Editar el backend | | ✔ | opc. | |
| Node.js 22 LTS + VS Code con *Vue (Official)* | Frontend (Nuxt 4) | ✔ | opc. | ✔ | `winget install OpenJS.NodeJS.LTS` |
| Tailscale | Llegar a la VM (solo opción VM) | ✔ | ✔ | ✔ | `winget install Tailscale.Tailscale` |
| DBeaver Community | Diagrama ER desde la BD real | | | ✔ | `winget install dbeaver.dbeaver` |

No instalen Azure Data Studio: Microsoft lo retiró y la extensión de VS Code lo reemplaza.

Verificación (cada uno pega el resultado en el grupo):

```powershell
git --version; pwsh --version; sqlcmd --version; dotnet --version; node --version
```

### 1.2 Conectarse al servidor compartido

**Opción VM + Tailscale** (la recomendada en el plan):

1. Acepten la invitación de Tailscale que les manda C por correo.
2. Abran Tailscale e inicien sesión con la cuenta invitada.
3. Prueben: `Test-NetConnection vm-techcare -Port 1433` debe responder `TcpTestSucceeded : True`.

**Opción Azure SQL** (sección 3):

1. Busquen su IP pública en https://ifconfig.me y mándensela a C por mensaje directo.
2. Cuando C confirme la regla de firewall, prueben: `Test-NetConnection techcare-grupo5.database.windows.net -Port 1433`.
3. Si falla desde la red de la universidad, prueben con el hotspot del celular: muchas redes de campus bloquean la salida al puerto 1433.

C les pasa su usuario (`dev_front`, `dev_back`) y la contraseña **por mensaje directo** o un *Send* de Bitwarden, nunca en el chat del grupo ni en git.

### 1.3 Clonar el repositorio

```powershell
cd ~\source
git clone https://github.com/<organizacion>/techcare.git
cd techcare
git config user.name "Su Nombre"; git config user.email "su@correo.com"
```

Estructura del repositorio:

```text
techcare/
├── .github/workflows/db-build.yml   check automático: construye la BD en cada PR
├── .github/pull_request_template.md
├── CODEOWNERS                       pide la revisión correcta según el archivo
├── database/                        scripts numerados, build, reconstrucción (ver database/README.md)
│   └── pruebas/                     un script por prueba T01–T14 (evidencia del entregable 08)
├── backend/TechCare.Api/            API .NET 8 (B)
├── frontend/                        Nuxt 4 (A)
└── docs/                            manuales, ER, normalización, plan de pruebas, esta guía
```

### 1.4 Crear su base personal

Cada uno tiene **su propia base** en el mismo servidor para experimentar sin romper la compartida (sección 2.2).

Forma corta (un solo comando; hace build, master, datos y auditoría):

```powershell
cd database
./reconstruir.ps1 -Servidor <SERVIDOR> -Usuario dev_front -Db TechCare_Front    # A
./reconstruir.ps1 -Servidor <SERVIDOR> -Usuario dev_back  -Db TechCare_Back     # B
./reconstruir.ps1 -Servidor <SERVIDOR> -Usuario dev_infra -Db TechCare_Infra    # C
# Azure: agregar -Azure (C crea antes las bases personales en el portal, sección 3.8)
```

Forma manual (la misma que aparece en las pestañas del plan):

```powershell
cd database
./build_master.ps1 -Db TechCare_Back                 # macOS: ./build_master.sh --db TechCare_Back
sqlcmd -S <SERVIDOR> -U dev_back -P *** -C -b -f 65001 -i build/TechCare_Back_Master.sql
```

Qué hace cada opción de `sqlcmd`: `-b` se detiene al primer error, `-f 65001` lee el archivo como UTF-8 (sin eso las tildes se dañan), `-C` confía en el certificado autofirmado de la VM (en Azure no se usa), `-d` elige la base destino.

**Conexión en SSMS:** *Server name* `<SERVIDOR>` · *Authentication* SQL Server Authentication · su login `dev_*` · *Encryption* Mandatory · marcar **Trust server certificate** (solo VM). En Azure, además: *Options >> Connection Properties >> Connect to database* = `TechCare` (o su base personal), porque los usuarios de Azure viven dentro de la base.

### 1.5 Revisar el modelo antes del congelamiento

Cada uno lee **hoy** la parte del núcleo que le toca defender y anota dudas:

| Quién | Qué leer |
|---|---|
| A | `02_tablas.sql` secciones 8 (Factura, DetalleFactura, MetodoPago, Pago) y 9 (Entrega); `10_funciones.sql`: `fn_TotalPagado`, `fn_SaldoFactura`, `fn_TotalOrden` |
| B | `02_tablas.sql` secciones 3 y 4 (órdenes, diagnóstico, reparación); `30_triggers_ordenes.sql`; `40_sp_comunes.sql`; `fn_UsuarioTieneRol` |
| C | `02_tablas.sql` secciones 5 a 7 (repuestos, inventario, compras, kárdex); `03_indices.sql`; `42_sp_inventario.sql` completo |

**Revisión del núcleo (lunes 19, 20:00, 45 minutos, los 3):** C comparte pantalla y recorren tabla por tabla. Lo que se acuerde se corrige en esa misma llamada. A las 22:00 C reconstruye la compartida y el núcleo queda congelado. Después de eso, cambiar una tabla cuesta una reconstrucción (sección 2.6).

### 1.6 Checklist "listo para trabajar"

- [ ] Las herramientas de mi rol responden con su versión.
- [ ] Llego al puerto 1433 del servidor compartido.
- [ ] Entro con SSMS o VS Code a `TechCare` y a mi base personal, y veo las 31 tablas.
- [ ] Cloné el repo, creé una rama de prueba e hice un PR de prueba que pasó el check `db-build` y que otro aprobó.
- [ ] Leí mi parte del núcleo y llevé mis dudas a la revisión de las 20:00.

---

## 2. Cómo trabajamos los 3 en la misma base de datos

### 2.1 La regla que lo ordena todo

**Git es la fuente de verdad; las bases de datos son copias desechables que se construyen desde git.** Nadie "arregla" algo directamente en SSMS. Si un objeto no está en un archivo de `database/` y mezclado en `main`, no existe, aunque esté en el servidor.

```text
  su editor ──► archivo .sql en su rama (a/…, b/…, c/…)
                    │ 1. lo despliega y prueba en SU base personal
                    ▼
               Pull Request ──► check automático db-build (SQL Server limpio en GitHub)
                    │           + revisión de otro integrante (A→B, B→C, C→A)
                    ▼
               merge a main
                    │ 2. el autor despliega SU archivo en la compartida TechCare y avisa
                    ▼
               TechCare (compartida) ◄── el backend de los 3 apunta aquí para integrar
                    │ 3. jueves 29: copia local para la demo
                    ▼
               Laptop de demostración
```

Nadie ejecuta nada en `TechCare` que no haya pasado por el check automático y por la revisión de otro integrante.

### 2.2 Tres entornos, cada uno con un propósito

| Base | Dónde | Quién escribe | Para qué | ¿Se puede romper? |
|---|---|---|---|---|
| `TechCare_Front`, `TechCare_Back`, `TechCare_Infra` | Mismo servidor (VM o Azure) | Solo su dueño | Laboratorio: probar su SP, su vista, sus datos | Sí: se reconstruye en un minuto |
| `TechCare` | Mismo servidor | Solo objetos ya mezclados en `main` | Integración: el backend de desarrollo apunta aquí, todos ven lo mismo | No; la reconstruye solo C, avisando |
| `TechCare` en la laptop de demo | Laptop (Docker o instalación local) | C, el jueves 29 | Demostración del 30, sin depender de internet | No se toca después del jueves |

Alternativa para la base personal: SQL Server en Docker en su propia laptop. Funciona sin internet y es su plan B si el servidor cae:

```powershell
docker run -d --name techcare-sql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Una_Clave_Fuerte_2026!' -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
./reconstruir.ps1 -Servidor localhost,1433 -Usuario sa -Db TechCare_Back
```

(En Mac con Apple Silicon, activen la emulación Rosetta en Docker Desktop.)

### 2.3 Un archivo, un dueño

Cada archivo de `database/` tiene **un solo dueño** (tabla en `database/README.md`); solo el dueño lo edita. Así no hay conflictos de merge y queda claro quién defiende qué. `CODEOWNERS` hace que GitHub pida automáticamente la revisión del dueño.

| Archivos | Dueño |
|---|---|
| `01`–`05`, `10`, `30`, `40` (núcleo) | Los 3 (cambios con el protocolo 2.6) |
| `20`, `41`, `50`, `80`, `83` | B |
| `21`, `31`, `42`, `51`, `81`, `82`, `85`, `90`, `91`, `92`, `limpiar_base.sql`, `reconstruir.*` | C |
| `22`, `43`, `52`, `84` | A |

- ¿Necesita algo en un archivo ajeno (por ejemplo, A necesita una columna más en `vw_InventarioActual` de C)? Pídalo en el grupo o en un *issue*; lo hace el dueño.
- Rangos de error para `THROW`: núcleo 50000–50099, inventario y compras 50100–50199, órdenes 50200–50299, facturación 50300–50399, triggers 51000–51099. El backend traduce todo el rango 50000–51099 a HTTP 422 con el mensaje tal cual.

### 2.4 El ciclo diario de cada integrante (ejemplo: B escribe `sp_RegistrarDiagnostico`)

1. **Actualizar y crear la rama** (prefijo `a/`, `b/` o `c/`):

   ```powershell
   git switch main; git pull
   git switch -c b/sp-registrar-diagnostico
   ```

2. **Si alguien cambió `02_tablas.sql` desde ayer, reconstruir su base personal** (`./reconstruir.ps1 -Servidor <SERVIDOR> -Usuario dev_back -Db TechCare_Back`). Si solo cambiaron vistas o SP, basta con volver a ejecutar esos archivos.

3. **Escribir** el objeto en **su** archivo (`41_sp_ordenes.sql`), siempre con `CREATE OR ALTER` (nunca `CREATE` solo, nunca `DROP` + `CREATE`).

4. **Desplegar solo ese archivo en su base personal:**

   ```powershell
   sqlcmd -S <SERVIDOR> -U dev_back -P *** -C -b -f 65001 -d TechCare_Back -i database/41_sp_ordenes.sql
   ```

   En SSMS: abrir el archivo, elegir `TechCare_Back` en el combo de bases y pulsar F5. Los archivos `02` en adelante no tienen `USE`: se ejecutan sobre la base conectada y se detienen solos si no es una base `TechCare…` (por ejemplo, si quedó en `master`).

5. **Probar** con un script en `database/pruebas/` (plantilla en 2.9): caso feliz, al menos un caso que debe fallar y un SELECT que muestre el resultado. Ese script es después la evidencia del plan de pruebas.

6. **Commit, push y Pull Request:**

   ```powershell
   git add database/41_sp_ordenes.sql database/pruebas/T03_diagnostico.sql
   git commit -m "db(ordenes): sp_RegistrarDiagnostico con validación de rol y estado"
   git push -u origin b/sp-registrar-diagnostico
   ```

   El check `db-build` ejecuta todo el master y los datos de prueba en un SQL Server 2022 limpio. Si falla, no se puede mezclar: abran la pestaña *Actions* del PR, el log dice el archivo y la línea.

7. **Revisión:** A revisa a B, B revisa a C, C revisa a A. El revisor **ejecuta** el archivo en su propia base personal y corre el script de prueba; no basta con leerlo. Es la mejor preparación para la defensa, porque todos terminan leyendo el SQL de todos.

8. **Merge y despliegue en la compartida.** Lo hace el autor, inmediatamente:

   ```powershell
   git switch main; git pull
   sqlcmd -S <SERVIDOR> -U dev_back -P *** -C -b -f 65001 -d TechCare -i database/41_sp_ordenes.sql
   ```

   Y avisa en el grupo: `Desplegado en TechCare: 41_sp_ordenes.sql (sp_RegistrarDiagnostico)`. Se despliega el **archivo completo**, no solo el SP nuevo: así la compartida queda idéntica a `main` para ese archivo. Como todo es `CREATE OR ALTER`, re-ejecutarlo no rompe nada.

### 2.5 Qué se puede re-ejecutar sin miedo

| Tipo de objeto | Cómo se despliega | ¿Pierde datos? | ¿Afecta a los otros? |
|---|---|---|---|
| Procedimiento, vista, función, trigger, reporte | Re-ejecutar su archivo (`CREATE OR ALTER`) | No | Solo si cambia la firma: avisar antes a quien lo consume |
| Datos de prueba (`80`–`85`) | Solo dentro de una reconstrucción completa | Si se ejecutan dos veces, se duplican | Sí |
| Tabla, columna, constraint, índice (núcleo) | Protocolo 2.6 + reconstrucción | Sí | Sí |
| Seguridad (`90`, `91`) y auditoría (`92`) | Re-ejecutar (son idempotentes) | No | No |

Si cambia la **firma** de un SP (parámetros o columnas devueltas), avisen a B (API) y a A (pantalla) **antes** de desplegar en la compartida. Agregar un parámetro **con valor por defecto** no rompe a nadie: es la forma preferida de hacer crecer un SP.

### 2.6 Cambios de tablas después del congelamiento

Un cambio de tabla obliga a reconstruir, así que se agrupan:

1. Se propone en el grupo con el motivo: *"necesito `Reparacion.garantiaDias INT NULL` para mostrar la garantía en la factura"*.
2. Si los 3 están de acuerdo, el solicitante abre una rama y edita `02_tablas.sql` (para que el master siga creando todo desde cero) y, si aplica, los datos de prueba.
3. **Lo aprueban los otros dos** (CODEOWNERS los pide a ambos para el núcleo).
4. C reconstruye `TechCare` en la siguiente ventana (2.7). Si no se puede reconstruir en ese momento, se aplica un script de `ALTER` puntual guardado en `database/cambios/AAAA-MM-DD_descripcion.sql`, que se ejecuta una vez en la compartida y **no** entra al master (el master ya tiene la versión nueva en `02_tablas.sql`):

   ```sql
   -- database/cambios/2026-10-22_reparacion_garantia.sql
   IF COL_LENGTH(N'dbo.Reparacion', N'garantiaDias') IS NULL
       ALTER TABLE dbo.Reparacion ADD garantiaDias INT NULL
           CONSTRAINT CK_Reparacion_Garantia CHECK (garantiaDias IS NULL OR garantiaDias BETWEEN 0 AND 365);
   ```

5. Cada uno reconstruye su base personal en cuanto pueda.

**Corte duro: después del lunes 26 no se cambian tablas**, porque ese día se genera el diagrama ER y debe coincidir exactamente con la BD final.

### 2.7 Reconstruir la base compartida

Solo C la reconstruye, porque `01_base_datos.sql` hace `DROP DATABASE` y desconecta a todos (`ROLLBACK IMMEDIATE`).

**Ventanas fijas: 13:00 y 21:00**, solo si hay algo que aplicar. Fuera de ventana, solo con el "sí" de los otros dos.

Aviso en el grupo, 15 minutos antes:

> 🔧 Reconstruyo **TechCare** (compartida) a las 21:00. Motivo: PR #14 (garantía en reparación). Cierren transacciones abiertas en SSMS y detengan el backend. Sus bases personales no se tocan.

Comando:

```powershell
cd database; git switch main; git pull
./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_infra                                   # VM
./reconstruir.ps1 -Servidor tcp:techcare-grupo5.database.windows.net,1433 -Usuario tcadmin -Azure  # Azure
```

El script pide escribir `SI` antes de tocar `TechCare`, y luego ejecuta en orden, deteniéndose al primer error: build → master → datos de prueba → seguridad (`90` en la VM, `91` en Azure) → auditoría DDL (`92`). `90_seguridad.sql` vuelve a crear los usuarios `dev_front` y `dev_back` dentro de la base, que se pierden con el `DROP DATABASE` (en las pestañas del plan esto aparece como un paso manual `post_rebuild.sql`; ya no hace falta).

Al terminar, C avisa: `✅ TechCare reconstruida desde main (commit a1b2c3d).`

Como los datos de prueba se generan con scripts, reconstruir no pierde nada. Y si la reconstrucción falla, es una buena noticia encontrada a tiempo: el master no corre desde cero, y ese es el entregable 02. Se corrige ese mismo día.

### 2.8 Git: ramas, check automático y Pull Requests

- **Ramas:** `a/…`, `b/…`, `c/…` según quién trabaja; ejemplos: `a/sp-registrar-pago`, `b/endpoints-ordenes`, `c/pantalla-compras`.
- **`main` protegida:** sin push directo; todo entra por PR con 1 aprobación y con el check `db-build` en verde.
- **Check `db-build`** (`.github/workflows/db-build.yml`): en cada PR que toque `database/`, levanta un SQL Server 2022 limpio en GitHub, genera el master con `build_master.sh`, lo ejecuta, ejecuta los datos de prueba y muestra el conteo de objetos. Es la red de seguridad para que un error de sintaxis nunca llegue a `TechCare`, y es la prueba continua de que el entregable 02 corre "desde una instancia vacía".
- **Commits pequeños** con prefijo: `db(...)`, `api(...)`, `web(...)`, `docs(...)`.
- **`.gitignore`** desde el primer commit: `bin/`, `obj/`, `*.user`, `appsettings.Development.json`, `node_modules/`, `.nuxt/`, `.output/`, `.env`, `database/build/`, `infra/`, `*.bak`.
- **Plantilla de PR** (`.github/pull_request_template.md`):

  ```markdown
  ## Qué cambia
  ## Cómo lo probé (base personal + script en database/pruebas/)
  - [ ] Usa CREATE OR ALTER
  - [ ] THROW con código de mi rango
  - [ ] Sin SELECT * ni DISTINCT para tapar duplicados
  - [ ] Ejecuté mi archivo en mi base personal sin errores
  - [ ] ¿Cambia la firma de un SP o de un endpoint? Avisé a quien lo usa
  ```

### 2.9 Probar sin ensuciar la base compartida

Plantilla de script de prueba (`database/pruebas/T05_utilizar_repuesto.sql`). La transacción externa permite ejecutar la prueba incluso en la compartida y dejarla exactamente como estaba:

```sql
/* T05: utilizar un repuesto con stock y comprobar detalle + salida + movimiento */
SET XACT_ABORT ON;
BEGIN TRANSACTION;                       -- todo lo de esta prueba se deshace al final

DECLARE @idReparacion INT = 1, @idBodega INT = 1, @idRepuesto INT = 3, @idTecnico INT = 5;

SELECT 'ANTES' AS momento, existencia
FROM dbo.Inventario
WHERE idBodega = @idBodega AND idRepuesto = @idRepuesto;

EXEC dbo.sp_UtilizarRepuesto @idReparacion = @idReparacion, @idBodega = @idBodega,
     @idRepuesto = @idRepuesto, @cantidad = 1, @idUsuario = @idTecnico;

SELECT 'DESPUÉS' AS momento, existencia
FROM dbo.Inventario
WHERE idBodega = @idBodega AND idRepuesto = @idRepuesto;

SELECT TOP (1) * FROM dbo.MovimientoInventario ORDER BY idMovimiento DESC;  -- en pruebas sí se vale SELECT *

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; -- quitar esta línea solo al generar evidencia en su base personal
```

Para casos que **deben fallar** (T04, T10), capturen el error para que el script siga y muestre el "después":

```sql
BEGIN TRY
    EXEC dbo.sp_RegistrarPago @idFactura = 7, @idMetodoPago = 1, @monto = 999999, @idUsuario = 8;
    PRINT 'ERROR DE PRUEBA: el pago excesivo NO fue rechazado';
END TRY
BEGIN CATCH
    PRINT CONCAT('OK, rechazado como se esperaba: ', ERROR_NUMBER(), ' - ', ERROR_MESSAGE());
END CATCH;

SELECT dbo.fn_SaldoFactura(7) AS saldoSinCambios;
```

Formato común de cada prueba (B lo consolida en el entregable 08): objetivo, datos de entrada, script, resultado esperado, resultado obtenido y captura. Para la evidencia, ejecuten en su base personal sin el `ROLLBACK` final.

### 2.10 Bloqueos: el problema más común al compartir una base

Si alguien ejecuta `BEGIN TRAN` en SSMS y olvida el `COMMIT` o el `ROLLBACK`, las filas quedan bloqueadas y la API de los demás se queda "colgada" esperando. Los SP usan `UPDLOCK`, así que lo notarán rápido.

Quién espera a quién, y quién tiene transacciones abiertas:

```sql
SELECT r.session_id           AS sesionEsperando,
       r.blocking_session_id  AS sesionBloqueando,
       r.wait_time / 1000     AS segundosEsperando,
       t.text                 AS sentenciaEsperando
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;

SELECT s.session_id, s.login_name, s.host_name, s.open_transaction_count, s.last_request_end_time
FROM sys.dm_exec_sessions s
WHERE s.open_transaction_count > 0;
```

(En la VM estas vistas necesitan `VIEW SERVER STATE`; C se lo da a `dev_front` y `dev_back` en C1. En Azure, `db_owner` ya puede verlas.)

Solución: el dueño de la sesión (columna `login_name`) hace `COMMIT` o `ROLLBACK` en su pestaña. Si no responde, C ejecuta `KILL <session_id>;` y esa transacción se revierte.

Hábitos que lo evitan: en la compartida nunca dejen una transacción abierta (las transacciones manuales se prueban en la base personal); si SSMS pregunta al cerrar *"¿confirmar transacciones abiertas?"*, algo quedó abierto: respondan **No**; detengan el backend cuando no lo usen.

Esto además es material de defensa: con dos ventanas de SSMS sobre la misma base pueden **demostrar** que `UPDLOCK` hace esperar al segundo técnico en `sp_UtilizarRepuesto` hasta que el primero confirma (háganlo en su base personal).

### 2.11 ¿La compartida coincide con `main`? Auditoría de cambios de esquema

`92_auditoria_ddl.sql` (de C) instala un trigger de base de datos que registra cada `CREATE`, `ALTER` y `DROP`: quién, cuándo, desde qué máquina y la sentencia completa. `reconstruir.ps1` lo instala en cada reconstrucción.

```sql
SELECT TOP (30) fecha, usuarioBD, host, evento, objeto
FROM dbo.AuditoriaDDL
ORDER BY idEvento DESC;
```

Si alguien cambió un objeto "a mano" (un despliegue que nadie avisó), el dueño vuelve a desplegar su archivo desde `main`. Ante la duda, gana `main`. Este trigger no forma parte del script maestro ni cuenta entre los 2 triggers del enunciado, pero pueden mostrarlo como buena práctica.

### 2.12 Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Conéctese primero a una base TechCare…` | Ejecutó un archivo estando en `master` | Elegir la base en el combo de SSMS, o `-d` en sqlcmd |
| `Could not find stored procedure` desde la API | El dueño no desplegó en la compartida después del merge | Desplegar el archivo (2.4, paso 8) |
| Tildes como `Ã³` en los datos | sqlcmd leyó el archivo sin UTF-8 | Usar siempre `-f 65001` |
| `There is already an object named…` al correr el master | Se ejecutó sobre una base con objetos (típico en Azure) | `reconstruir.ps1 -Azure` ya ejecuta `limpiar_base.sql` antes |
| Datos de prueba duplicados | Se corrió `TechCare_DatosPrueba.sql` dos veces | Reconstruir completo |
| Error 3915 al llamar un SP desde un script de datos | Usó `INSERT … EXEC` con un SP que tiene transacción | Ejecutar el SP con `EXEC` y recuperar el id por su llave de negocio |
| Login falla en Azure (error 18456) | No indicó la base: los usuarios contenidos viven en `TechCare`, no en `master` | SSMS → *Connect to database: TechCare*; sqlcmd → `-d TechCare` |
| Primera conexión a Azure tarda o falla (error 40613) | La base estaba en pausa automática y está despertando | Reintentar a los 60 segundos |
| El check `db-build` falla pero en mi base funciona | Su base tiene algo que no está en git, o depende del orden de ejecución | Reconstruir su base desde cero y reproducir |

### 2.13 Comunicación

- **Daily** de 15 minutos, todos los días a las 20:30 (antes de la ventana de las 21:00): qué terminé, qué sigo, qué me bloquea.
- **Mensajes obligatorios en el grupo:** cada despliegue en la compartida, cada reconstrucción (antes y después), cada cambio de firma de un SP o de un endpoint.
- **Tablero** (GitHub Projects o Trello) con una tarjeta por SP, vista, reporte, endpoint y pantalla, con su dueño.

---

## 3. Opción Azure SQL Database, paso a paso

Azure conviene si la VM no es confiable o no quieren mantenerla: la base vive en la nube, siempre accesible y con respaldo automático, sin Tailscale. Puede costar cero con la oferta gratuita de Azure SQL Database: hasta 10 bases por suscripción, cada una con 100,000 vCore-segundos de cómputo serverless al mes, 32 GB de datos y 32 GB de respaldo, renovados cada mes calendario ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer)).

### 3.1 VM + Tailscale frente a Azure

| Criterio | VM Windows Server + Tailscale | Azure SQL Database (oferta gratuita) |
|---|---|---|
| Costo | 0 (ya tienen la VM) | 0 dentro de la cuota |
| Disponibilidad | Depende de que la VM esté encendida y con internet | Siempre disponible; se pausa sola si no se usa |
| Acceso | Tailscale en cada laptop, sin abrir puertos | Regla de firewall con la IP pública de cada integrante |
| Motor | SQL Server 2022, idéntico al de la demo | Azure SQL, casi idéntico (diferencias en 3.10) |
| Respaldo | `BACKUP DATABASE` programado | Automático (7 días de restauración) |
| Riesgo principal | La VM se apaga o pierde la red | La IP de alguien cambia, o se agota la cuota |
| Montaje | ~1.5 h | ~45 min |

Decidan en 10 minutos y no intenten ambas: elijan una y la otra queda como plan B.

### 3.2 Antes de crear: la cuenta y una decisión importante

- **Cuenta:** lo ideal es **Azure for Students**: 100 USD de crédito por 12 meses, sin tarjeta de crédito, registrándose con el correo de la universidad ([Microsoft](https://azure.microsoft.com/en-us/free/students)). Solo C necesita la suscripción; los demás se conectan con usuarios de base de datos.
- Ojo: la variante **Azure for Students Starter** no es compatible con la oferta gratuita de SQL ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer)).
- **El límite gratuito puede alcanzarse antes del 30.** Una base serverless consume al menos su vCore mínimo (0.5) por cada segundo que está encendida, aunque nadie la use. Así, 100,000 vCore-segundos son aproximadamente **55 horas encendida al mes** por base. La cuota de octubre se renueva el 1 de noviembre, **después** de la entrega. Ver 3.9 para elegir el comportamiento al llegar al límite.

### 3.3 Crear el servidor y la base compartida (C, ~20 minutos)

1. Entrar a https://portal.azure.com, abrir el hub de Azure SQL (https://aka.ms/azuresqlhub) y en *Create a database* elegir **Start free**. Debe aparecer el aviso **"Free offer applied!"**; si no aparece, vuelvan a elegir el servidor en el desplegable.
2. Pestaña **Basics**:
   - *Subscription*: la suya. *Resource group*: **Create new** → `rg-techcare`.
   - *Database name*: `TechCare`.
   - *Server*: **Create new** → nombre único en todo Azure, por ejemplo `techcare-grupo5` (queda `techcare-grupo5.database.windows.net`); región cercana (por ejemplo *South Central US* o *East US 2*). Todas las bases gratuitas de la suscripción deben quedar en esa misma región, y no se puede cambiar después.
   - *Authentication method*: **Use SQL authentication**; *Server admin login*: `tcadmin` + contraseña fuerte, guardada en un gestor de contraseñas.
   - *Behavior when free limit reached*: según 3.9.
3. Pestaña **Networking**: *Connectivity method* **Public endpoint**; *Add current client IP address* **Yes**; *Allow Azure services and resources to access this server* **No** (el backend corre en sus laptops).
4. Pestaña **Additional settings**: *Collation* = **`Modern_Spanish_CI_AS`**, igual que en la VM. La intercalación solo se elige al crear la base; si la olvidan, borren la base y créenla de nuevo.
5. Confirmar que la tarjeta *Cost summary* muestre 0 al mes → **Review + create** → **Create**.

### 3.4 Dar acceso a los otros dos (firewall)

Azure SQL rechaza toda IP que no tenga regla. Cada integrante necesita la suya.

**Desde el portal:** servidor `techcare-grupo5` → *Security* → **Networking** → *Firewall rules* → **Add a firewall rule** → nombre `A-casa`, IP inicial y final iguales → **Save**.

**Desde T-SQL** (más rápido; conectado a la base **master** con `tcadmin`):

```sql
EXECUTE sp_set_firewall_rule @name = N'A-casa', @start_ip_address = '190.56.10.20', @end_ip_address = '190.56.10.20';
EXECUTE sp_set_firewall_rule @name = N'B-casa', @start_ip_address = '181.174.5.6',  @end_ip_address = '181.174.5.6';
EXECUTE sp_set_firewall_rule @name = N'C-casa', @start_ip_address = '200.6.200.7',  @end_ip_address = '200.6.200.7';
SELECT name, start_ip_address, end_ip_address FROM sys.firewall_rules;   -- revisar
EXECUTE sp_delete_firewall_rule @name = N'A-casa';                       -- quitar una vieja
```

(Las IP del ejemplo son inventadas; usen las reales de https://ifconfig.me.)

- Las IP residenciales suelen cambiar: es el detalle más molesto de Azure. Si un día no conectan, revisen su IP y pídanle a C que actualice **su** regla (mismo nombre, IP nueva; `sp_set_firewall_rule` la reemplaza).
- Para no depender de C: C puede darles acceso al grupo de recursos (*rg-techcare* → *Access control (IAM)* → *Add role assignment* → **SQL Server Contributor** → invitar su correo), y cada uno edita su regla en el portal.
- **Nunca** creen una regla `0.0.0.0 – 255.255.255.255`: deja la base abierta a todo internet.

### 3.5 Desplegar el esquema

En Azure no se ejecuta `01_base_datos.sql`: la base se crea en el portal, `USE` no cambia de base y `ALTER DATABASE … SINGLE_USER` no existe. Por eso el build tiene la variante `--azure` / `-Azure`, que omite el `01` y quita los `USE`.

Un solo comando (hace `limpiar_base.sql`, master, datos, `91_seguridad_azure.sql` y `92_auditoria_ddl.sql`):

```powershell
cd database
./reconstruir.ps1 -Servidor tcp:techcare-grupo5.database.windows.net,1433 -Usuario tcadmin -Azure
```

O paso a paso (sin `-C`, porque el certificado de Azure es válido):

```bash
cd database
./build_master.sh --azure          # omite 01 (la base ya existe) y no usa USE
sqlcmd -S tcp:techcare-grupo5.database.windows.net,1433 -d TechCare -U tcadmin -P '***' -b -f 65001 -i build/TechCare_Azure_Master.sql
sqlcmd -S tcp:techcare-grupo5.database.windows.net,1433 -d TechCare -U tcadmin -P '***' -b -f 65001 -i 91_seguridad_azure.sql
sqlcmd -S tcp:techcare-grupo5.database.windows.net,1433 -d TechCare -U tcadmin -P '***' -b -f 65001 -i build/TechCare_Azure_DatosPrueba.sql
```

`limpiar_base.sql` existe porque en Azure no se puede hacer `DROP DATABASE` desde el script: borra todos los objetos (tablas, vistas, SP, funciones, tipos, secuencias) y conserva usuarios y roles, para volver a ejecutar el master sobre una base vacía.

### 3.6 Usuarios: contenidos dentro de la base

En Azure SQL Database no se usa `CREATE LOGIN` para cada persona: se usan **usuarios contenidos**, que viven dentro de la base con su propia contraseña. `91_seguridad_azure.sql` crea:

| Usuario | Para quién | Permisos |
|---|---|---|
| `techcare_app` | El backend | Ejecutar SP y leer; escribir solo en catálogos (lo mismo que `90_seguridad.sql`) |
| `dev_front`, `dev_back`, `dev_infra` | A, B, C | `db_owner` de la base |
| `tcadmin` | C (administrador del servidor) | Todo; solo para reconstruir y gestionar el firewall |

Antes de ejecutarlo, C cambia las contraseñas en su copia local del archivo (sin hacer commit de ese cambio) y se las pasa a cada uno por mensaje directo.

Al conectarse con un usuario contenido **hay que indicar la base**: `-d TechCare` en sqlcmd, o en SSMS *Options → Connection Properties → Connect to database* = `TechCare`. Si se deja en `<default>`, Azure busca el usuario en `master` y el login falla. DBeaver y VS Code: mismos datos, base `TechCare`.

### 3.7 Cadena de conexión del backend

```text
Server=tcp:techcare-grupo5.database.windows.net,1433;Database=TechCare;User Id=techcare_app;Password=***;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;
```

El timeout de 60 segundos cubre la primera conexión después de una pausa automática, que tarda alrededor de un minuto. Se guarda con `dotnet user-secrets` (sección 5), nunca en `appsettings.json`.

### 3.8 Bases personales en Azure

Cada base gratuita tiene **su propia cuota**, así que conviene que el desarrollo diario pegue a las personales y la compartida se use solo para integrar:

1. C repite 3.3 eligiendo el **mismo servidor** `techcare-grupo5`, con los nombres `TechCare_Front`, `TechCare_Back` y `TechCare_Infra` (cada una con *Free offer applied!* y collation `Modern_Spanish_CI_AS`). Entran en el límite de 10 bases gratuitas.
2. C construye cada una la primera vez, porque `91` crea ahí los usuarios:

   ```powershell
   ./reconstruir.ps1 -Servidor tcp:techcare-grupo5.database.windows.net,1433 -Usuario tcadmin -Azure -Db TechCare_Back
   ```

3. Desde ahí, cada uno reconstruye la suya con su propio usuario (`-Usuario dev_back -Azure -Db TechCare_Back`), porque `limpiar_base.sql` conserva los usuarios.

Alternativa sin gastar cuota: base personal en Docker local (2.2) y solo la compartida en Azure.

### 3.9 Cuidar la cuota gratuita

- **Cierren SSMS** (incluido el *Object Explorer*) y **detengan el backend** al terminar: una conexión abierta impide la pausa y sigue consumiendo cuota ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer)).
- Trabajen en su base personal (cuota propia).
- C crea una **alerta** sobre la métrica *Free amount remaining* por debajo de 10,000 segundos, como recomienda Microsoft. La cuota restante también se ve en la base → *Overview* → *Free monthly vCore amount*.

**Qué elegir en *Behavior when free limit reached*** (si eligen continuar, no se puede volver atrás):

| Su suscripción | Elijan | Por qué |
|---|---|---|
| Azure for Students (crédito de 100 USD, sin tarjeta) | **Continue using database for additional charges** | El excedente se descuenta del crédito, no de una tarjeta, y la base **no se pausa** a mitad de semana. Para una base de este tamaño, unos días de excedente son una fracción pequeña del crédito. |
| Cuenta con tarjeta de crédito | **Auto-pause the database until next month** | No hay cobros, pero si se agota la cuota la base queda **en pausa hasta el 1 de noviembre**. No lo recomiendo con la entrega el 30, salvo que mantengan siempre la copia local de 3.11. |

### 3.10 Qué cambia frente a SQL Server en la VM

| Tema | VM / local | Azure SQL Database | Cómo lo resolvimos |
|---|---|---|---|
| Crear y borrar la base | Script `01` | Portal | El build `-Azure` omite el `01`; `limpiar_base.sql` vacía la base |
| `USE otraBase` | Funciona | No cambia de base | Los scripts `02` en adelante no usan `USE`; se conecta con `-d` |
| Usuarios | `CREATE LOGIN` + `CREATE USER` (`90_seguridad.sql`) | Usuarios contenidos (`91_seguridad_azure.sql`) | Un script para cada caso |
| Aislamiento por defecto | READ COMMITTED con bloqueos | READ COMMITTED **SNAPSHOT** | Los SP leen stock, saldo y estado con `UPDLOCK`, así que se comportan igual en ambos |
| Respaldo | `BACKUP DATABASE` a `.bak` | Automático (restauración a un punto en el tiempo de hasta 7 días); no hay `.bak` | Exportar `.bacpac` (3.11) |
| Acceso | Tailscale | Reglas de firewall por IP | 3.4 |
| SP, triggers, funciones, `SESSION_CONTEXT`, secuencias, TVP, índices filtrados, `STRING_AGG` | ✔ | ✔ | El proyecto no requiere cambios de código |

### 3.11 La demo del 30 no depende de Azure

La red de la universidad puede bloquear el puerto 1433 y la base puede estar en pausa. El plan B es el mismo de siempre: el master y los datos de prueba reconstruyen todo en una instancia local en minutos. Esa es la razón principal para generar los datos con scripts y no a mano. El jueves 29, C deja la base en la laptop de demostración:

1. **Reconstruida desde los scripts** (la forma que más valora el profesor, porque prueba el entregable 02): SQL Server Developer o Docker en la laptop y `./reconstruir.ps1 -Servidor localhost -Usuario sa`.
2. **Copia exacta de la compartida**, por si tiene datos que vale la pena conservar:

   ```powershell
   dotnet tool install -g microsoft.sqlpackage
   sqlpackage /Action:Export /SourceServerName:tcp:techcare-grupo5.database.windows.net,1433 /SourceDatabaseName:TechCare /SourceUser:tcadmin /SourcePassword:*** /TargetFile:TechCare.bacpac
   sqlpackage /Action:Import /SourceFile:TechCare.bacpac /TargetServerName:localhost /TargetDatabaseName:TechCare /TargetUser:sa /TargetPassword:*** /TargetTrustServerCertificate:True
   ```

Después de la entrega, borren el grupo de recursos `rg-techcare` (*Delete resource group*) para que nada quede corriendo.

---

## 4. Paso a paso de C · Fullstack / Infra

C desbloquea a los demás: hasta que la BD esté accesible y el repo exista, A y B trabajan con datos simulados. **Meta del lunes 19: que los tres se conecten a una base `TechCare` ya creada a las 18:00.** Además, C construye el dominio de **inventario, compras y auditoría** y es responsable de que el sistema se pueda reconstruir en cualquier máquina.

### C1 · Infraestructura (lunes 19)

**Decidan primero VM o Azure (10 minutos).** Si la VM está siempre encendida y tienen acceso de administrador: VM + Tailscale. Si no: Azure (sección 3).

**Opción VM (~1.5 h):**

- [ ] **SQL Server 2022 Developer** (instalador oficial → *Custom* → *Database Engine Services*), autenticación **modo mixto** (Windows + SQL). Anoten la contraseña de `sa`; no la usen en la app.
- [ ] **TCP/IP:** *SQL Server Configuration Manager* → *SQL Server Network Configuration* → *Protocols for MSSQLSERVER* → *TCP/IP: Enabled*. En *IP Addresses → IPAll*: `TCP Port = 1433` y `TCP Dynamic Ports` vacío. Reiniciar el servicio.
- [ ] **Tailscale** en la VM: iniciar sesión con la cuenta del equipo; en la consola de administración, renombrar la máquina a `vm-techcare` y activar **Disable key expiry**. Invitar a A y B (*Users → Invite*).
- [ ] **Firewall de Windows**, abriendo 1433 solo para la red de Tailscale (PowerShell como administrador):

  ```powershell
  New-NetFirewallRule -DisplayName "SQL Server via Tailscale" -Direction Inbound `
    -Protocol TCP -LocalPort 1433 -RemoteAddress 100.64.0.0/10 -Action Allow
  ```

- [ ] **Logins de desarrollo** (una sola vez; conectado como `sa` a `master`). Los logins sobreviven a las reconstrucciones:

  ```sql
  USE master;
  CREATE LOGIN dev_front WITH PASSWORD = N'<clave-front>', CHECK_POLICY = ON;
  CREATE LOGIN dev_back  WITH PASSWORD = N'<clave-back>',  CHECK_POLICY = ON;
  CREATE LOGIN dev_infra WITH PASSWORD = N'<clave-infra>', CHECK_POLICY = ON;

  -- dbcreator: cada uno puede crear y reconstruir su base personal
  ALTER SERVER ROLE dbcreator ADD MEMBER dev_front;
  ALTER SERVER ROLE dbcreator ADD MEMBER dev_back;
  ALTER SERVER ROLE dbcreator ADD MEMBER dev_infra;

  -- C administra la VM: con sysadmin puede ejecutar 90_seguridad.sql (crea un login)
  ALTER SERVER ROLE sysadmin ADD MEMBER dev_infra;

  -- Para diagnosticar bloqueos (2.10)
  GRANT VIEW SERVER STATE TO dev_front;
  GRANT VIEW SERVER STATE TO dev_back;
  ```

  Si prefieren no dar `sysadmin` a `dev_infra`, ejecuten `90_seguridad.sql` la primera vez con `sa`: después, como `techcare_app` ya existe, `dev_infra` puede reconstruir solo con `dbcreator`. Advertencia: `dbcreator` puede borrar cualquier base; por eso `reconstruir.ps1` pide escribir `SI` antes de tocar `TechCare`.

- [ ] **Respaldo diario** (Programador de tareas de Windows, 23:00):

  ```powershell
  sqlcmd -S localhost -E -Q "BACKUP DATABASE TechCare TO DISK = N'C:\Backups\TechCare.bak' WITH INIT, COMPRESSION;"
  ```

**Opción Azure (~45 min):** sección 3 completa. En Azure los logins los reemplaza `91_seguridad_azure.sql` y el respaldo es automático.

**Para las dos opciones:**

- [ ] **Primera construcción de `TechCare` (lo más importante del día).** Si `sqlcmd` marca un error, la salida dice el archivo y la línea: corríjanlo en `database/`, regeneren y vuelvan a correr (el script empieza borrando la base, así que se puede repetir).

  ```powershell
  cd database
  ./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_infra
  # o, a mano:
  ./build_master.ps1
  sqlcmd -S vm-techcare,1433 -U dev_infra -P *** -C -b -f 65001 -i build/TechCare_Master.sql
  sqlcmd -S vm-techcare,1433 -U dev_infra -P *** -C -b -f 65001 -i 90_seguridad.sql
  ```

- [ ] Cambiar las contraseñas de `90_seguridad.sql` / `91_seguridad_azure.sql` **en su copia local** antes de ejecutarlos (sin commit).
- [ ] Verificar los objetos. Hoy deben salir 31 tablas, 1 vista, 6 procedimientos (los 3 de referencia y los 3 modelo), 4 funciones escalares y 1 trigger (más la tabla `AuditoriaDDL` si se instaló el `92`; su trigger de base de datos se ve en `sys.triggers`, no en `sys.objects`):

  ```sql
  SELECT type_desc, COUNT(*) AS cantidad
  FROM sys.objects
  WHERE is_ms_shipped = 0 AND type IN ('U', 'V', 'P', 'FN', 'IF', 'TR')
  GROUP BY type_desc;
  ```

- [ ] Prueba de humo del trigger: `UPDATE dbo.OrdenServicio SET estado = 'ENTREGADO' WHERE 1 = 0;` no debe fallar. Cuando ya existan usuarios y equipos de prueba, un `INSERT` directo de una orden con `estado = 'LISTO'` debe fallar con el error 51001.
- [ ] Compartir servidor, usuario y contraseña con A y B por mensaje directo o un *Send* de Bitwarden.
- [ ] 20:00 revisión del núcleo con A y B; 22:00 reconstrucción final y congelamiento.

### C2 · Repo e integración (lunes 19 – martes 20)

- [ ] Crear el repo **privado** en GitHub e invitar a A, B (y al profesor, si lo pide) con permiso *Write*. Subir `database/`, `.github/workflows/db-build.yml`, `docs/` (con esta guía) y crear las carpetas `backend/`, `frontend/`, `database/pruebas/`.
- [ ] `.gitignore` desde el primer commit:

  ```text
  # .NET
  bin/
  obj/
  *.user
  appsettings.Development.json
  # Node / Nuxt
  node_modules/
  .nuxt/
  .output/
  .env
  # BD
  database/build/
  infra/
  *.bak
  ```

- [ ] `CODEOWNERS` en la raíz, para que GitHub pida automáticamente la revisión correcta (reemplazar por los usuarios reales):

  ```text
  /database/0*            @usuarioA @usuarioB @usuarioC
  /database/10_*          @usuarioA @usuarioB @usuarioC
  /database/30_*          @usuarioA @usuarioB @usuarioC
  /database/40_*          @usuarioA @usuarioB @usuarioC
  /database/*ordenes*     @usuarioB
  /database/*inventario*  @usuarioC
  /database/*facturacion* @usuarioA
  /backend/               @usuarioB
  /frontend/              @usuarioA
  ```

- [ ] Proteger `main` (*Settings → Branches → Add rule*): **Require a pull request before merging** con 1 aprobación y **Require status checks to pass** marcando `db-build`. Desde ahí nadie empuja directo a `main`.
- [ ] Abrir un PR de prueba que solo cambie un comentario en `database/` y verificar en la pestaña *Actions* que el check `db-build` corre y pasa. **Este es el primer lugar donde los scripts se ejecutan contra un SQL Server real**: si falla, se corrige hoy.
- [ ] Plantilla de PR en `.github/pull_request_template.md` (texto en 2.8).
- [ ] Tablero (GitHub Projects) con una tarjeta por objeto de BD, endpoint y pantalla, con su dueño.
- [ ] **Conectar front y back** en su laptop (martes 20, cuando B tenga el login): backend en `https://localhost:7xxx` con CORS para `http://localhost:3000`; frontend con `NUXT_PUBLIC_API_BASE=https://localhost:7xxx/api` en `frontend/.env`. Hagan juntos el primer login de punta a punta: es cuando aparecen los problemas de CORS, HTTPS y JWT. Si el navegador rechaza el certificado de desarrollo: `dotnet dev-certs https --trust`.
- [ ] Empezar el `README.md` de la raíz con lo que hizo hoy (se completa el 27).

### C3 · Dominio de BD: inventario, compras y auditoría (martes 20 – jueves 22)

Trabaja en `TechCare_Infra` y en `21_vistas_inventario.sql`, `31_triggers_auditoria.sql` y `42_sp_inventario.sql`. Códigos de error 50100–50199 (triggers 51010–51099). Antes de escribir, lee `sp_UtilizarRepuesto` completo: es tu plantilla y uno de los SP que defenderás.

**`sp_RegistrarCompra` (martes 20)**

- [ ] Firma: `@idProveedor INT, @idBodegaDestino INT, @numeroDocumento VARCHAR(30), @idUsuario INT, @detalle dbo.TipoDetalleCompra READONLY, @observaciones NVARCHAR(300) = NULL`. El parámetro de tabla (TVP) trae todas las líneas en una sola llamada: encabezado y detalle entran en la misma transacción.
- [ ] Validaciones antes de `BEGIN TRAN`: rol `BODEGA` con `fn_UsuarioTieneRol`; `IF NOT EXISTS (SELECT 1 FROM @detalle)` → `THROW`; proveedor y bodega activos; todos los repuestos existen y están activos (`LEFT JOIN dbo.Repuesto` desde `@detalle` y buscar `r.idRepuesto IS NULL OR r.estado <> 'ACTIVO'`).
- [ ] Dentro de la transacción: `INSERT dbo.Compra` (estado PENDIENTE por DEFAULT), `DECLARE @idCompra INT = SCOPE_IDENTITY()`, `INSERT dbo.DetalleCompra SELECT @idCompra, idRepuesto, cantidad, costoUnitario FROM @detalle`. Devolver `SELECT @idCompra AS idCompra`.
- [ ] Probarlo en SSMS:

  ```sql
  DECLARE @d dbo.TipoDetalleCompra;
  INSERT INTO @d (idRepuesto, cantidad, costoUnitario) VALUES (1, 10, 150.00), (2, 5, 420.50);
  EXEC dbo.sp_RegistrarCompra @idProveedor = 1, @idBodegaDestino = 1,
       @numeroDocumento = 'FAC-1001', @idUsuario = 4, @detalle = @d;
  ```

**`sp_RecibirCompra` (miércoles 21): transacción estrella para la defensa (R08, T06)**

Ya está escrito en `42_sp_inventario.sql`. El truco que lo hace limpio y *set-based* es la cláusula `OUTPUT`: en un solo `UPDATE` suma las existencias de todas las líneas y captura el valor anterior (`deleted`) y el nuevo (`inserted`) de cada fila, que es justo lo que pide el kárdex.

```sql
CREATE OR ALTER PROCEDURE dbo.sp_RecibirCompra
    @idCompra  INT,
    @idUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'BODEGA') = 0
        THROW 50110, 'El usuario no tiene rol de bodega.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @idBodega INT, @estado VARCHAR(10);

        -- Bloquea la compra: dos personas no pueden recibirla a la vez
        SELECT @idBodega = c.idBodegaDestino, @estado = c.estado
        FROM dbo.Compra c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.idCompra = @idCompra;

        IF @estado IS NULL        THROW 50111, 'La compra no existe.', 1;
        IF @estado <> 'PENDIENTE' THROW 50112, 'Solo se puede recibir una compra PENDIENTE.', 1;

        -- 1. Repuestos que aún no están en esa bodega: crear su fila con existencia 0
        INSERT INTO dbo.Inventario (idBodega, idRepuesto, existencia)
        SELECT @idBodega, dc.idRepuesto, 0
        FROM dbo.DetalleCompra dc
        WHERE dc.idCompra = @idCompra
          AND NOT EXISTS (SELECT 1 FROM dbo.Inventario i
                          WHERE i.idBodega = @idBodega AND i.idRepuesto = dc.idRepuesto);

        -- 2. Sumar existencias y capturar antes/después de cada fila
        DECLARE @mov TABLE (idRepuesto INT PRIMARY KEY, anterior INT, resultante INT);

        UPDATE i
           SET i.existencia = i.existencia + dc.cantidad,
               i.fechaUltimoMovimiento = SYSDATETIME()
        OUTPUT inserted.idRepuesto, deleted.existencia, inserted.existencia
          INTO @mov (idRepuesto, anterior, resultante)
        FROM dbo.Inventario i
        INNER JOIN dbo.DetalleCompra dc ON dc.idRepuesto = i.idRepuesto
        WHERE dc.idCompra = @idCompra
          AND i.idBodega = @idBodega;

        -- 3. Un movimiento ENTRADA por línea, con su documento origen (CK_Movimiento_Cuadre lo verifica)
        INSERT INTO dbo.MovimientoInventario
            (idBodega, idRepuesto, tipo, origen, cantidad, existenciaAnterior, existenciaResultante,
             costoUnitario, idUsuario, idCompra)
        SELECT @idBodega, m.idRepuesto, 'ENTRADA', 'COMPRA', dc.cantidad, m.anterior, m.resultante,
               dc.costoUnitario, @idUsuario, @idCompra
        FROM @mov m
        INNER JOIN dbo.DetalleCompra dc ON dc.idCompra = @idCompra AND dc.idRepuesto = m.idRepuesto;

        -- 4. Cerrar la compra (CK_Compra_Recepcion exige fecha y usuario)
        UPDATE dbo.Compra
           SET estado = 'RECIBIDA', fechaRecepcion = SYSDATETIME(), idUsuarioRecepcion = @idUsuario
         WHERE idCompra = @idCompra;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
```

- [ ] Ejecutarlo en tu base y probar: recibir una compra (las existencias suben y aparecen movimientos), intentar recibirla otra vez (error 50112) y verificar que `existenciaResultante` del movimiento coincide con `Inventario.existencia`.
- [ ] Opcional (sirve para T14): en el paso 4, actualizar también `Repuesto.precioCompraRef` al último costo; así el trigger de auditoría registra el cambio de precio.
- [ ] `sp_AnularCompra` (opcional, R14): solo si está PENDIENTE; estado ANULADA y motivo en observaciones.

**`sp_AjusteInventario` (miércoles 21)**

- [ ] Firma: `@idBodega, @idRepuesto, @cantidad INT` (positiva suma, negativa resta), `@idUsuario, @motivo NVARCHAR(250)`.
- [ ] Motivo obligatorio y `@cantidad <> 0` antes de la transacción. Dentro: leer la existencia con `UPDLOCK, HOLDLOCK` (igual que `sp_UtilizarRepuesto`), verificar que el resultado no sea negativo, `UPDATE Inventario` e insertar el movimiento con `tipo` = ENTRADA o SALIDA según el signo, `cantidad = ABS(@cantidad)`, `origen = 'AJUSTE'` y `observacion = @motivo` (el CHECK de origen lo exige).

**Triggers de auditoría (jueves 22), archivo 31**

- [ ] `trg_Repuesto_AuditoriaPrecio` (T14). Siempre *set-based*: un `UPDATE` de precios a 20 repuestos debe dejar 20 filas.

  ```sql
  CREATE OR ALTER TRIGGER dbo.trg_Repuesto_AuditoriaPrecio
  ON dbo.Repuesto
  AFTER UPDATE
  AS
  BEGIN
      SET NOCOUNT ON;
      IF NOT (UPDATE(precioVenta) OR UPDATE(precioCompraRef)) RETURN;

      INSERT INTO dbo.AuditoriaPrecioRepuesto
          (idRepuesto, precioCompraAnterior, precioCompraNuevo, precioVentaAnterior, precioVentaNuevo, idUsuario)
      SELECT i.idRepuesto, d.precioCompraRef, i.precioCompraRef, d.precioVenta, i.precioVenta,
             TRY_CAST(SESSION_CONTEXT(N'idUsuario') AS INT)
      FROM inserted i
      INNER JOIN deleted d ON d.idRepuesto = i.idRepuesto
      WHERE i.precioVenta <> d.precioVenta
         OR i.precioCompraRef <> d.precioCompraRef;
  END;
  ```

- [ ] `trg_MovimientoInventario_Inmutable`: `INSTEAD OF UPDATE, DELETE` con un solo `THROW 51010, 'Los movimientos de inventario no se modifican ni eliminan; registre un ajuste.', 1;`. Prueba: `DELETE FROM dbo.MovimientoInventario WHERE idMovimiento = 1;` debe fallar. Es la demostración más rápida de R14 en la defensa.
- [ ] Para que el backend registre quién cambió un precio, B debe llamar `EXEC dbo.sp_EstablecerContexto @idUsuario` en la misma conexión justo antes del `UPDATE Repuesto`. Coordínalo con B.

**Vistas (jueves 22), archivo 21**

- [ ] `vw_InventarioActual`: columnas y `estadoStock` (`SIN_STOCK`, `BAJO_MINIMO`, `OK`) como dice el comentario del archivo. La usan el dashboard, los reportes 6 y 7, y la pantalla de inventario.
- [ ] `vw_MovimientosInventario`: `LEFT JOIN` a `Compra`/`Proveedor` y a `DetalleRepuesto → Reparacion → Diagnostico → OrdenServicio`, porque cada movimiento tiene solo uno de los dos orígenes. Columna `documentoOrigen` con un `CASE` por `origen`. Esta vista es tu mejor ejemplo de por qué un `LEFT JOIN` es necesario y no un capricho.

**Frontend y API de tu dominio (jueves 22)**

- [ ] Controladores de inventario y compras en la API siguiendo el patrón de B (sección 5); B revisa tu PR.
- [ ] Pantallas `/inventario`, `/inventario/kardex`, `/compras` y `/compras/nueva` (líneas dinámicas que viajan como TVP; botón *Recibir*), siguiendo los patrones de A (sección 6); A revisa tu PR.

### C4 · Reportes 5–9 y datos de prueba (viernes 23 – lunes 26)

**Reportes (archivo 51).** Cada reporte es un SP con filtros opcionales del tipo `WHERE (@idBodega IS NULL OR i.idBodega = @idBodega)`. Sin `SELECT *`, sin `DISTINCT`, alias legibles.

| SP | Parámetros | Columnas clave | Detalle técnico |
|---|---|---|---|
| `sp_Reporte_05_RepuestosUtilizados` | `@fechaInicio`, `@fechaFin`, `@idTecnico`, `@idBodega` | orden, técnico, bodega, repuesto, cantidad, costo, venta, margen | 7 tablas con INNER JOIN; usa precio y costo **del detalle**, no del catálogo |
| `sp_Reporte_06_Inventario` | `@idBodega`, `@idCategoria` | bodega, categoría, repuesto, existencia, valor | Sobre `vw_InventarioActual` |
| `sp_Reporte_07_BajoMinimo` | `@idBodega` | repuesto, existencia, mínimo, faltante | `WHERE existencia <= stockMinimo`, ordenado por faltante |
| `sp_Reporte_08_ComprasProveedor` | `@idProveedor`, `@fechaInicio`, `@fechaFin` | proveedor, documento, fecha, estado, repuesto, cantidad, costo, subtotal | 6 tablas; incluye compras PENDIENTES |
| `sp_Reporte_09_Kardex` | `@idBodega`, `@idRepuesto`, `@fechaInicio`, `@fechaFin` | fecha, tipo, origen, documento, cantidad, anterior, resultante, usuario | Sobre `vw_MovimientosInventario`; usa el índice IX5 |

**Datos de prueba: organización.** Para que los tres aporten sin conflictos de merge, los datos se dividen en seis archivos (el build los une en orden en `TechCare_DatosPrueba.sql`):

| Archivo | Dueño | Contenido |
|---|---|---|
| `80_datos_usuarios.sql` | B (lo genera su comando de seed) | 10+ usuarios con hash real y sus roles |
| `81_datos_maestros.sql` | C | 30+ clientes (uno sin órdenes), 45+ equipos, 30+ repuestos, filas de inventario con `stockMinimo`, 8+ proveedores |
| `82_datos_compras.sql` | C | 20+ compras con `sp_RegistrarCompra`; recibir 17 con `sp_RecibirCompra` y dejar 3 PENDIENTES |
| `83_datos_ordenes.sql` | B | 60+ órdenes, 45+ diagnósticos, 35+ reparaciones, consumo de repuestos, en todos los estados |
| `84_datos_facturacion.sql` | A | 30+ facturas y 40+ pagos (parciales, completos, varios métodos), entregas |
| `85_datos_escenarios.sql` | C | Fechas repartidas, casos para la defensa y verificación de mínimos |

Regla de oro: todo lo transaccional se crea **llamando a los SP**. Si un SP falla al generar datos, encontraron un bug antes que el profesor. Para recuperar el id que creó un SP, búsquenlo por su llave de negocio (por ejemplo `SELECT @idCompra = idCompra FROM dbo.Compra WHERE idProveedor = 1 AND numeroDocumento = 'FAC-1001';`); no usen `INSERT … EXEC` con SP que tienen transacción (error 3915).

**Escenarios que deben existir** (los usarán en la demostración):

- [ ] Un repuesto con existencia 0 en una bodega y existencia en otra (T04).
- [ ] 3 o más repuestos bajo el mínimo (reporte 7, dashboard).
- [ ] Un equipo con 3 o más órdenes (reporte 3, T11). Ojo: `sp_RegistrarOrdenServicio` no permite dos órdenes abiertas del mismo equipo, así que la anterior debe llegar a ENTREGADO antes de crear la siguiente.
- [ ] Una factura con saldo pendiente, una con 3 pagos y una pagada completa (reporte 10, T09, T10).
- [ ] Una orden en cada estado, incluida una CANCELADA con motivo.
- [ ] Un cliente sin órdenes (prueba del LEFT JOIN del reporte 2).
- [ ] Una orden sin diagnóstico, una diagnosticada pero no reparada, una reparación con varios repuestos y una compra pendiente de recibir (escenarios obligatorios del enunciado).

**Repartir fechas sin romper las reglas.** Los SP usan `SYSDATETIME()`, así que todo nace con la fecha de hoy. Para que los reportes por período tengan sentido, `85_datos_escenarios.sql` mueve cada orden y todo lo que cuelga de ella **el mismo número de días hacia atrás**, así los CHECK de fechas (`fechaFin >= fechaInicio`, etc.) se siguen cumpliendo:

```sql
-- Desplazamiento por orden: entre 0 y 89 días hacia atrás
DECLARE @d TABLE (idOrden INT PRIMARY KEY, dias INT);
INSERT INTO @d SELECT idOrden, (idOrden * 7) % 90 FROM dbo.OrdenServicio;

UPDATE o SET o.fechaIngreso = DATEADD(DAY, -d.dias, o.fechaIngreso),
             o.fechaEstimada = DATEADD(DAY, -d.dias, o.fechaEstimada)
FROM dbo.OrdenServicio o JOIN @d d ON d.idOrden = o.idOrden;

UPDATE g SET g.fechaDiagnostico = DATEADD(DAY, -d.dias, g.fechaDiagnostico),
             g.fechaRespuestaCliente = DATEADD(DAY, -d.dias, g.fechaRespuestaCliente)
FROM dbo.Diagnostico g JOIN @d d ON d.idOrden = g.idOrden;
-- Igual para Reparacion (vía Diagnostico), HistorialEstadoOrden, Factura, Pago (vía Factura) y Entrega.
```

`MovimientoInventario` tiene el trigger de inmutabilidad; si necesitan mover sus fechas, desactívenlo solo dentro de este script (`DISABLE TRIGGER … ; … ; ENABLE TRIGGER …`) y explíquenlo en el manual técnico como algo exclusivo de los datos de prueba.

- [ ] Al final del 85, un bloque de verificación que cuente cada tabla contra el mínimo del enunciado (sección 7) y muestre `OK` o `FALTA`. Es la evidencia de que cumplen los volúmenes:

  ```sql
  SELECT entidad, total, minimo, CASE WHEN total >= minimo THEN 'OK' ELSE 'FALTA' END AS resultado
  FROM (VALUES
      ('Usuarios',     (SELECT COUNT(*) FROM dbo.Usuario),              10),
      ('Clientes',     (SELECT COUNT(*) FROM dbo.Cliente),              30),
      ('Equipos',      (SELECT COUNT(*) FROM dbo.Equipo),               45),
      ('Órdenes',      (SELECT COUNT(*) FROM dbo.OrdenServicio),        60),
      ('Diagnósticos', (SELECT COUNT(*) FROM dbo.Diagnostico),          45),
      ('Reparaciones', (SELECT COUNT(*) FROM dbo.Reparacion),           35),
      ('Repuestos',    (SELECT COUNT(*) FROM dbo.Repuesto),             30),
      ('Bodegas',      (SELECT COUNT(*) FROM dbo.Bodega),                3),
      ('Inventario',   (SELECT COUNT(*) FROM dbo.Inventario),           60),
      ('Proveedores',  (SELECT COUNT(*) FROM dbo.Proveedor),             8),
      ('Compras',      (SELECT COUNT(*) FROM dbo.Compra),               20),
      ('Movimientos',  (SELECT COUNT(*) FROM dbo.MovimientoInventario), 100),
      ('Facturas',     (SELECT COUNT(*) FROM dbo.Factura),              30),
      ('Pagos',        (SELECT COUNT(*) FROM dbo.Pago),                 40)
  ) AS v (entidad, total, minimo);
  ```

- [ ] Integrar `80`–`85`: reconstruir la compartida con los datos de los 3 y revisar el resultado del bloque anterior.
- [ ] Backend apuntando a `techcare_app` (no a `dev_*`): probar que `UPDATE dbo.Inventario SET existencia = 99` con ese usuario falla por permisos. Es una demostración muy convincente de que "el stock no se modifica desde una pantalla".

### C5 · Pruebas, documentos y demo (domingo 25 – viernes 30)

**Tus pruebas** (un script por prueba en `database/pruebas/`, con captura del resultado):

| Prueba | Qué ejecutar | Qué debe verse |
|---|---|---|
| T04 | `sp_UtilizarRepuesto` pidiendo más de lo que hay en la bodega | Error 50106 y ningún cambio en `Inventario`, `DetalleRepuesto` ni `MovimientoInventario` (SELECT antes y después) |
| T05 | `sp_UtilizarRepuesto` válido | Detalle con precio histórico, existencia descontada y un movimiento SALIDA que cuadra |
| T06 | `sp_RegistrarCompra` + `sp_RecibirCompra` | Existencias suben, un movimiento ENTRADA por línea, compra RECIBIDA |
| T07 | Script de demo con error a mitad de transacción (abajo) | ROLLBACK: nada quedó a medias |
| T13 | Abrir `vw_InventarioActual` y el dashboard | `BAJO_MINIMO` / `SIN_STOCK` correctos en varias bodegas |
| T14 | `UPDATE Repuesto SET precioVenta = …` y abrir una factura vieja | La factura conserva su precio; aparece la fila en `AuditoriaPrecioRepuesto` |

**Demo de T07** (el error lo provoca una constraint real, no un `THROW` inventado):

```sql
SET XACT_ABORT ON;
SELECT existencia AS antes FROM dbo.Inventario WHERE idBodega = 1 AND idRepuesto = 3;
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE dbo.Inventario SET existencia = existencia - 1 WHERE idBodega = 1 AND idRepuesto = 3;
        -- existenciaResultante incorrecta a propósito: CK_Movimiento_Cuadre la rechaza
        INSERT INTO dbo.MovimientoInventario (idBodega, idRepuesto, tipo, origen, cantidad,
               existenciaAnterior, existenciaResultante, idUsuario, observacion)
        VALUES (1, 3, 'SALIDA', 'AJUSTE', 1, 10, 999, 1, N'Demo T07');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT('ROLLBACK por error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;
SELECT existencia AS despues FROM dbo.Inventario WHERE idBodega = 1 AND idRepuesto = 3;   -- igual que antes
```

**Documentos a tu cargo:**

- [ ] **Diagrama ER (lunes 26):** DBeaver → conexión a `TechCare` → *Schemas → dbo* → clic derecho → *View Diagram*. Acomodar las tablas por módulo (como la tabla 6.1 del plan) y exportar a PNG y PDF en `docs/`. Al generarse de la BD real, coincide exactamente con lo implementado. Después de exportarlo, no se tocan tablas.
- [ ] **Documento de normalización:** para 1FN, 2FN y 3FN, un ejemplo real del modelo. 1FN: los repuestos de una reparación van en `DetalleRepuesto`, no en una columna con una lista. 2FN: en `Inventario` (PK bodega + repuesto) la existencia depende de ambas columnas, mientras que el nombre del repuesto depende solo de `idRepuesto` y por eso vive en `Repuesto`. 3FN: la orden no guarda el cliente porque depende del equipo. Agrega las decisiones de la sección 6.3 del plan, incluidas las desnormalizaciones justificadas (`Inventario.existencia` y los totales de `Factura`).
- [ ] **README de ejecución (martes 27):** requisitos, crear la BD con el master y los datos, configurar `user-secrets` y `.env`, levantar API y frontend, usuarios de prueba con sus contraseñas. Valídalo siguiendo **solo** lo que dice, en una máquina limpia.
- [ ] **Script maestro y datos de prueba finales** (entregables 02 y 03): `./build_master.ps1` el jueves 29 después del congelamiento; renombrar según pida el profesor.

**Laptop de demostración (jueves 29):**

- [ ] Instancia local (SQL Server Developer o Docker, comando en 2.2) y `./reconstruir.ps1 -Servidor localhost -Usuario sa`, o restaurar el `.bak` de la VM con `RESTORE DATABASE TechCare FROM DISK = '…' WITH MOVE …`. Apuntar el backend a `localhost` con `techcare_app`.
- [ ] Ensayar la demo completa **sin internet** (modo avión). Si algo depende de la red, se descubre ahí y no frente al profesor.
- [ ] Dejar abiertos en SSMS los scripts de demo: T04, T07, el `DELETE` sobre movimientos (R14), el `UPDATE` a ENTREGADO con saldo (R16) y las dos ventanas para demostrar el bloqueo con `UPDLOCK`.

**Lo que debes poder explicar en la defensa:** `sp_UtilizarRepuesto` y `sp_RecibirCompra` línea por línea (`UPDLOCK`/`HOLDLOCK`, `OUTPUT`, `XACT_ABORT`, por qué el CHECK de cuadre en movimientos); por qué `Inventario.existencia` se guarda aunque se podría calcular; los 10 índices y qué consulta mejora cada uno; el usuario `techcare_app` y por qué no puede modificar inventario directamente; la infraestructura (VM + Tailscale o Azure).

---

## 5. Paso a paso de B · Backend

B es el puente entre la BD y la pantalla: la API autentica, autoriza y llama SP; **nunca arma INSERT/UPDATE de procesos**. Su primer entregable para el equipo es el **contrato de endpoints en Swagger el martes 20**, aunque responda datos simulados, para que A no espere. Además construye el dominio de **órdenes, diagnóstico y reparación**.

### B1 · Preparación (lunes 19)

- [ ] Instalar .NET 8 SDK, Visual Studio 2022 Community o Rider (o VS Code + C# Dev Kit), Git, SSMS 21 o VS Code + MSSQL, `sqlcmd` y Tailscale (o mandar su IP a C si usan Azure).
- [ ] Crear su base personal `TechCare_Back` (1.4).
- [ ] Revisar el modelo antes del congelamiento (1.5). Si algo no le cuadra, dígalo hoy.
- [ ] Copiar al repo su código existente de usuarios y hash (.NET 8) en una rama `b/auth`.

### B2 · La API paso a paso (lunes 19 – miércoles 21)

**Proyecto y paquetes:**

```powershell
cd backend
dotnet new webapi -n TechCare.Api --use-controllers -f net8.0
cd TechCare.Api
dotnet add package Dapper
dotnet add package Microsoft.Data.SqlClient
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer --version 8.*
dotnet add package FluentValidation.DependencyInjectionExtensions
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:TechCare" "Server=vm-techcare,1433;Database=TechCare_Back;User Id=dev_back;Password=***;TrustServerCertificate=True"
dotnet user-secrets set "Jwt:Key" "<cadena aleatoria de 64+ caracteres>"
```

`appsettings.json` (sin secretos):

```json
{
  "Jwt": { "Issuer": "techcare-api", "Audience": "techcare-web" },
  "Cors": { "Front": "http://localhost:3000" }
}
```

Estructura sugerida:

```text
backend/TechCare.Api/
├── Program.cs
├── Controllers/     uno por área: Auth, Clientes, Ordenes, Reparaciones, Inventario, Compras, Facturas, Reportes, Usuarios
├── Data/            SqlConnectionFactory + un repositorio por dominio:
│                    OrdenesRepository, InventarioRepository, FacturacionRepository, ReportesRepository
├── Dtos/            records de entrada y salida + validadores FluentValidation
├── Auth/            su código reutilizado: hash de contraseñas y emisión de JWT
└── Middleware/      SqlErrorMiddleware, UserExtensions
```

Mientras desarrolla, apunte a su base personal; cuando el SP esté en `main`, cambie la cadena a `TechCare`.

**Llamar un SP con Dapper (el patrón de toda la API):**

```csharp
using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

public sealed class SqlConnectionFactory(IConfiguration cfg)
{
    public SqlConnection Create() => new(cfg.GetConnectionString("TechCare"));
}

public sealed class OrdenesRepository(SqlConnectionFactory db)
{
    public async Task<OrdenCreadaDto> RegistrarAsync(RegistrarOrdenDto dto, int idUsuario)
    {
        await using var cn = db.Create();
        return await cn.QuerySingleAsync<OrdenCreadaDto>(
            "dbo.sp_RegistrarOrdenServicio",
            new { dto.IdEquipo, idUsuarioRecepcion = idUsuario, dto.ProblemaReportado,
                  dto.Prioridad, dto.FechaEstimada, dto.Observaciones },
            commandType: CommandType.StoredProcedure);
    }
}

public record RegistrarOrdenDto(int IdEquipo, string ProblemaReportado, string Prioridad = "MEDIA",
                                DateTime? FechaEstimada = null, string? Observaciones = null);
public record OrdenCreadaDto(int IdOrden, string NumeroOrden);
```

Validación de backend con FluentValidation (requisito 6.4: validar en la interfaz **y** en el backend):

```csharp
using FluentValidation;

public sealed class RegistrarOrdenValidator : AbstractValidator<RegistrarOrdenDto>
{
    public RegistrarOrdenValidator()
    {
        RuleFor(x => x.IdEquipo).GreaterThan(0);
        RuleFor(x => x.ProblemaReportado).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Prioridad).Must(p => p is "BAJA" or "MEDIA" or "ALTA" or "URGENTE");
    }
}
// Program.cs: builder.Services.AddValidatorsFromAssemblyContaining<RegistrarOrdenValidator>();
// En el controlador: inyectar IValidator<RegistrarOrdenDto> y llamar ValidateAsync antes del repositorio.
```

Para la compra con detalle (TVP, la usa C) y para el reporte 12 (varios result sets, lo usa A):

```csharp
var dt = new DataTable();
dt.Columns.Add("idRepuesto", typeof(int));
dt.Columns.Add("cantidad", typeof(int));
dt.Columns.Add("costoUnitario", typeof(decimal));
foreach (var l in dto.Lineas) dt.Rows.Add(l.IdRepuesto, l.Cantidad, l.CostoUnitario);
var idCompra = await cn.QuerySingleAsync<int>("dbo.sp_RegistrarCompra",
    new { dto.IdProveedor, dto.IdBodegaDestino, dto.NumeroDocumento, idUsuario,
          detalle = dt.AsTableValuedParameter("dbo.TipoDetalleCompra") },
    commandType: CommandType.StoredProcedure);

using var grid = await cn.QueryMultipleAsync("dbo.sp_Reporte_12_Trazabilidad",
    new { idOrden }, commandType: CommandType.StoredProcedure);
var encabezado = await grid.ReadSingleAsync<TrazaEncabezadoDto>();
var repuestos  = (await grid.ReadAsync<TrazaRepuestoDto>()).ToList();
// ... movimientos, pagos, historial, en el mismo orden que el SP
```

Mantenimientos simples (clientes, equipos, repuestos, usuarios): SQL parametrizado directo es válido, por ejemplo `cn.ExecuteAsync("UPDATE dbo.Cliente SET telefono = @telefono WHERE idCliente = @id", new { telefono, id })`. **Nunca** concatenar valores del usuario en el SQL.

**Login, JWT y permisos:**

- [ ] `POST /api/auth/login`: busca el usuario por `username` con SQL parametrizado, verifica el hash con su código existente (rechaza si `estado = 'INACTIVO'`), carga sus roles y permisos, actualiza `ultimoAcceso` y devuelve el token y `{ idUsuario, nombreCompleto, roles, permisos }`. Si el usuario no existe, está inactivo o la contraseña no coincide, la respuesta es **la misma**: 401 "Usuario o contraseña incorrectos", para no revelar qué usuarios existen.

  ```sql
  SELECT idUsuario, username, passwordHash, nombreCompleto, estado
  FROM dbo.Usuario
  WHERE username = @username;

  SELECT r.nombre
  FROM dbo.UsuarioRol ur
  INNER JOIN dbo.Rol r ON r.idRol = ur.idRol
  WHERE ur.idUsuario = @idUsuario;

  SELECT p.codigo
  FROM dbo.UsuarioRol ur
  INNER JOIN dbo.RolPermiso rp ON rp.idRol = ur.idRol
  INNER JOIN dbo.Permiso p     ON p.idPermiso = rp.idPermiso
  WHERE ur.idUsuario = @idUsuario
  GROUP BY p.codigo;            -- un usuario con 2 roles puede recibir el mismo permiso dos veces

  UPDATE dbo.Usuario SET ultimoAcceso = SYSDATETIME() WHERE idUsuario = @idUsuario;
  ```

- [ ] Claims del token: `NameIdentifier` = idUsuario, un `Role` por rol y un claim `permiso` por cada permiso. Duración: 8 horas.

  ```csharp
  using System.IdentityModel.Tokens.Jwt;
  using System.Security.Claims;
  using System.Text;
  using Microsoft.IdentityModel.Tokens;

  var claims = new List<Claim>
  {
      new(ClaimTypes.NameIdentifier, u.IdUsuario.ToString()),
      new(ClaimTypes.Name, u.Username),
      new("nombre", u.NombreCompleto)
  };
  claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));
  claims.AddRange(permisos.Select(p => new Claim("permiso", p)));

  var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(cfg["Jwt:Key"]!));
  var token = new JwtSecurityToken(cfg["Jwt:Issuer"], cfg["Jwt:Audience"], claims,
      expires: DateTime.UtcNow.AddHours(8),
      signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

  return Ok(new
  {
      token = new JwtSecurityTokenHandler().WriteToken(token),
      usuario = new { idUsuario = u.IdUsuario, nombreCompleto = u.NombreCompleto, roles, permisos }
  });
  ```

- [ ] Una política por permiso y `[Authorize(Policy = "ORDEN_CREAR")]` en cada endpoint:

  ```csharp
  string[] permisos = ["USUARIO_GESTIONAR", "CLIENTE_GESTIONAR", "ORDEN_CREAR", "ORDEN_CAMBIAR_ESTADO",
      "DIAGNOSTICO_REGISTRAR", "REPARACION_GESTIONAR", "REPUESTO_CONSUMIR", "CATALOGO_GESTIONAR",
      "COMPRA_REGISTRAR", "COMPRA_RECIBIR", "FACTURA_EMITIR", "PAGO_REGISTRAR", "ENTREGA_REGISTRAR", "REPORTE_VER"];
  builder.Services.AddAuthorization(o =>
  {
      foreach (var p in permisos) o.AddPolicy(p, pol => pol.RequireClaim("permiso", p));
  });
  ```

- [ ] El `idUsuario` que se manda a los SP sale **siempre del token**, nunca del cuerpo de la petición. Si en la defensa preguntan cómo evitan que un usuario se haga pasar por otro, esta es la respuesta:

  ```csharp
  using System.Security.Claims;

  public static class UserExtensions
  {
      public static int IdUsuario(this ClaimsPrincipal user) =>
          int.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier) ?? throw new UnauthorizedAccessException());
  }
  ```

- [ ] **Comando para generar los usuarios de prueba con hash real** (hoy mismo, para que el login funcione desde el día 1): `dotnet run -- generar-usuarios > ../../database/80_datos_usuarios.sql`. Que escriba los `INSERT` de 10+ usuarios (2 por rol, una contraseña de prueba conocida y documentada en el manual de usuario) y sus `UsuarioRol`. Así los datos de prueba tienen hashes reales y se cumple el CHECK de longitud del hash. Al inicio de `Program.cs`:

  ```csharp
  if (args is ["generar-usuarios"])
  {
      var hasher = new PasswordService();                 // su clase existente
      string[] roles = ["ADMINISTRADOR", "RECEPCION", "TECNICO", "BODEGA", "CAJA"];
      Console.WriteLine("-- Generado por: dotnet run -- generar-usuarios. Contraseña de prueba: Demo2026!");
      foreach (var rol in roles)
          for (var n = 1; n <= 2; n++)
          {
              var username = $"{rol.ToLowerInvariant()}{n}";
              Console.WriteLine($"""
                  INSERT INTO dbo.Usuario (username, passwordHash, nombreCompleto, email)
                  VALUES ('{username}', '{hasher.Hash("Demo2026!")}', N'{rol} {n} de prueba', '{username}@techcare.test');
                  INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
                  SELECT u.idUsuario, r.idRol FROM dbo.Usuario u CROSS JOIN dbo.Rol r
                  WHERE u.username = '{username}' AND r.nombre = '{rol}';
                  """);
          }
      return;
  }
  ```

  Aquí sí se arma SQL con texto porque es un generador de datos de prueba con valores fijos, no una consulta con entrada de usuarios. En la API, siempre parámetros. El archivo generado debe empezar con la misma guarda que los demás (`IF DB_NAME() NOT LIKE N'TechCare%' …`): cópienla del encabezado que trae `80_datos_usuarios.sql`.

**Errores de negocio → HTTP:**

```csharp
using Microsoft.Data.SqlClient;

public sealed class SqlErrorMiddleware(RequestDelegate next)
{
    public async Task Invoke(HttpContext ctx)
    {
        try { await next(ctx); }
        catch (SqlException ex) when (ex.Number is >= 50000 and <= 51099)
        { await Write(ctx, 422, ex.Message); }                    // THROW de los SP y triggers
        catch (SqlException ex) when (ex.Number is 2627 or 2601)
        { await Write(ctx, 409, "Ya existe un registro con ese valor único."); }
        catch (SqlException ex) when (ex.Number == 547)
        { await Write(ctx, 409, "La operación viola una regla de integridad de la base de datos."); }
    }

    static Task Write(HttpContext ctx, int status, string msg)
    {
        ctx.Response.StatusCode = status;
        return ctx.Response.WriteAsJsonAsync(new { error = msg });   // A lee response._data.error
    }
}
```

**`Program.cs` completo:**

```csharp
using System.Text;
using FluentValidation;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

// (aquí va el bloque "generar-usuarios")

var builder = WebApplication.CreateBuilder(args);
var cfg = builder.Configuration;

builder.Services.AddControllers();
builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<OrdenesRepository>();          // y los demás repositorios
builder.Services.AddValidatorsFromAssemblyContaining<RegistrarOrdenValidator>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT", In = ParameterLocation.Header
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }] = []
    });
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,   ValidIssuer = cfg["Jwt:Issuer"],
        ValidateAudience = true, ValidAudience = cfg["Jwt:Audience"],
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(cfg["Jwt:Key"]!)),
        ValidateLifetime = true
    });

// (aquí va el bloque de políticas por permiso)

builder.Services.AddCors(o => o.AddPolicy("front", p =>
    p.WithOrigins(cfg["Cors:Front"]!).AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

app.UseMiddleware<SqlErrorMiddleware>();   // antes de autenticación, para capturar todo
app.UseSwagger();
app.UseSwaggerUI();                         // botón Authorize para probar con JWT
app.UseCors("front");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

- [ ] Checklist B2: Swagger abre; `POST /api/auth/login` devuelve un token con permisos; un endpoint protegido responde 401 sin token y 403 sin el permiso; un `THROW` de prueba llega como 422 con `{ "error": "…" }`.

**Contrato de endpoints (publicar en Swagger el martes 20):**

| Método y ruta | Objeto de BD | Política | Implementa |
|---|---|---|---|
| `POST /api/auth/login` | consulta parametrizada | anónimo | B |
| `GET/POST/PUT /api/clientes`, `/api/equipos` | consultas parametrizadas | CLIENTE_GESTIONAR | B |
| `GET /api/catalogos/{tipo}` | TipoEquipo, Marca, Bodega, MetodoPago, CategoriaRepuesto | autenticado | B |
| `GET /api/ordenes?estado=&idTecnico=` | `vw_OrdenesActivas` | REPORTE_VER | B |
| `GET /api/ordenes/{id}` | `sp_Reporte_12_Trazabilidad` (pantalla central de A) | REPORTE_VER | B |
| `POST /api/ordenes` | `sp_RegistrarOrdenServicio` | ORDEN_CREAR | B |
| `POST /api/ordenes/{id}/estado` | `sp_CambiarEstadoOrden` | ORDEN_CAMBIAR_ESTADO | B |
| `POST /api/ordenes/{id}/diagnostico` | `sp_RegistrarDiagnostico` | DIAGNOSTICO_REGISTRAR | B |
| `POST /api/ordenes/{id}/autorizacion` | `sp_RegistrarAutorizacionCliente` | ORDEN_CAMBIAR_ESTADO | B |
| `POST /api/ordenes/{id}/reparacion` | `sp_IniciarReparacion` | REPARACION_GESTIONAR | B |
| `POST /api/reparaciones/{id}/actividades` | `sp_RegistrarActividad` | REPARACION_GESTIONAR | B |
| `POST /api/reparaciones/{id}/repuestos` | `sp_UtilizarRepuesto` | REPUESTO_CONSUMIR | B |
| `POST /api/reparaciones/{id}/finalizar` | `sp_FinalizarReparacion` | REPARACION_GESTIONAR | B |
| `GET /api/inventario`, `POST /api/inventario/ajustes` | `vw_InventarioActual`, `sp_AjusteInventario` | REPORTE_VER / CATALOGO_GESTIONAR | C |
| `POST /api/compras`, `POST /api/compras/{id}/recibir` | `sp_RegistrarCompra`, `sp_RecibirCompra` | COMPRA_REGISTRAR / COMPRA_RECIBIR | C |
| CRUD `/api/repuestos`, `/api/proveedores` | consultas parametrizadas | CATALOGO_GESTIONAR | C |
| `POST /api/ordenes/{id}/factura` | `sp_FacturarOrden` | FACTURA_EMITIR | B |
| `GET /api/facturas?conSaldo=true` | `vw_FacturasSaldo` (pantalla de caja de A) | PAGO_REGISTRAR | B |
| `POST /api/facturas/{id}/pagos`, `POST /api/pagos/{id}/anular` | `sp_RegistrarPago`, `sp_AnularPago` | PAGO_REGISTRAR | B |
| `POST /api/ordenes/{id}/entrega` | `sp_EntregarOrden` | ENTREGA_REGISTRAR | B |
| `GET /api/dashboard` | `vw_DashboardResumen` | REPORTE_VER | B |
| `GET /api/reportes/{n}` | `sp_Reporte_NN_*` | REPORTE_VER | B |
| CRUD `/api/usuarios` | consultas parametrizadas + hash | USUARIO_GESTIONAR | B |

C implementa los controladores de inventario y compras siguiendo su patrón, y B revisa su PR. Para cambiar precios de repuestos, el endpoint llama `EXEC dbo.sp_EstablecerContexto @idUsuario` en la **misma conexión** justo antes del `UPDATE`, para que el trigger de auditoría de C sepa quién lo hizo.

### B3 · Dominio de BD: órdenes, diagnóstico y reparación (lunes 19 – jueves 22)

Trabaja en `TechCare_Back` y en `20_vistas_ordenes.sql`, `41_sp_ordenes.sql` y `50_reportes_ordenes.sql`. Códigos de error 50200–50299. Defiende además el trigger `trg_OrdenServicio_Estado` y `fn_UsuarioTieneRol`: léalos hoy.

**Regla clave de su dominio: para cambiar el estado de una orden dentro de un SP**, no llame a `sp_CambiarEstadoOrden` (serían transacciones anidadas). Haga `EXEC dbo.sp_EstablecerContexto @idUsuario, N'motivo'` y luego `UPDATE dbo.OrdenServicio SET estado = …`. El trigger valida la transición y escribe el historial con su usuario.

**`sp_RegistrarOrdenServicio` (lunes 19 – martes 20): modelo completo.** Ya está escrito en `41_sp_ordenes.sql`; es el ejemplo del patrón para los demás:

```sql
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarOrdenServicio
    @idEquipo            INT,
    @idUsuarioRecepcion  INT,
    @problemaReportado   NVARCHAR(500),
    @prioridad           VARCHAR(10)   = 'MEDIA',
    @fechaEstimada       DATE          = NULL,
    @observaciones       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuarioRecepcion, 'RECEPCION') = 0
        THROW 50201, 'El usuario no tiene rol de recepción.', 1;

    IF NULLIF(LTRIM(RTRIM(@problemaReportado)), N'') IS NULL
        THROW 50202, 'Debe describir el problema reportado.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Bloquea el equipo: dos recepcionistas no pueden abrirle orden al mismo tiempo
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Equipo e WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN dbo.Cliente c ON c.idCliente = e.idCliente
            WHERE e.idEquipo = @idEquipo
              AND e.estado = 'ACTIVO'
              AND c.estado = 'ACTIVO')
            THROW 50203, 'El equipo no existe, no está activo o su cliente está inactivo.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.OrdenServicio o
            INNER JOIN dbo.EstadoOrden eo ON eo.codigo = o.estado
            WHERE o.idEquipo = @idEquipo
              AND eo.esFinal = 0)
            THROW 50204, 'El equipo ya tiene una orden abierta.', 1;

        EXEC dbo.sp_EstablecerContexto @idUsuario = @idUsuarioRecepcion, @observacion = N'Orden registrada';

        INSERT INTO dbo.OrdenServicio
            (idEquipo, idUsuarioRecepcion, problemaReportado, prioridad, fechaEstimada, observaciones)
        VALUES
            (@idEquipo, @idUsuarioRecepcion, @problemaReportado, @prioridad, @fechaEstimada, @observaciones);

        -- SCOPE_IDENTITY y no @@IDENTITY: el trigger inserta en HistorialEstadoOrden,
        -- y @@IDENTITY devolvería el id del historial, no el de la orden.
        DECLARE @idOrden INT = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;
        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;

        SELECT o.idOrden, o.numeroOrden
        FROM dbo.OrdenServicio o
        WHERE o.idOrden = @idOrden;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;
        THROW;
    END CATCH;
END;
```

- [ ] Probar: orden válida (debe aparecer una fila en `HistorialEstadoOrden` con `estadoAnterior` NULL); segunda orden al mismo equipo (error 50204); usuario de Caja (error 50201); prioridad `'XYZ'` (error del CHECK, 547).

**Los otros cinco SP (martes 20 – jueves 22):**

- [ ] **`sp_RegistrarDiagnostico`** (`@idOrden, @idTecnico, @descripcion, @costoManoObraEstimado`): rol TECNICO; leer la orden con `UPDLOCK`; debe estar en RECIBIDO o DIAGNOSTICO; sin diagnóstico previo; `INSERT Diagnostico`. Si estaba en RECIBIDO: `UPDATE … SET estado = 'DIAGNOSTICO', idTecnicoAsignado = ISNULL(idTecnicoAsignado, @idTecnico)` y luego un segundo `UPDATE` a ESPERANDO_AUTORIZACION. Son dos transiciones válidas, así que quedan dos filas en el historial: así se ve el recorrido real.
- [ ] **`sp_RegistrarAutorizacionCliente`** (`@idOrden, @autorizado BIT, @idUsuario`): orden en ESPERANDO_AUTORIZACION; diagnóstico con `autorizado IS NULL`; guardar `autorizado` y `fechaRespuestaCliente` juntos (el CHECK los exige a la par). Si `@autorizado = 0`, la orden pasa a LISTO (se devuelve sin reparar y sin factura).
- [ ] **`sp_IniciarReparacion`** (`@idOrden, @idTecnico`): rol TECNICO; diagnóstico con `autorizado = 1`; orden en ESPERANDO_AUTORIZACION; `INSERT Reparacion` con `idDiagnostico` (esta FK NOT NULL es R04 a nivel de BD); orden a REPARACION. Devolver `idReparacion`.
- [ ] **`sp_RegistrarActividad`** (`@idReparacion, @idTecnico, @descripcion, @horas`): reparación EN_PROCESO; `SELECT @n = ISNULL(MAX(numeroActividad), 0) + 1 FROM ActividadReparacion WITH (UPDLOCK, HOLDLOCK) WHERE idReparacion = @idReparacion` dentro de la transacción, para que dos técnicos no generen el mismo número.
- [ ] **`sp_FinalizarReparacion`** (`@idReparacion, @idTecnico, @descripcionTrabajo, @costoManoObra`): reparación EN_PROCESO; `estado = 'FINALIZADA'`, `fechaFin = SYSDATETIME()`, costo final; la orden pasa a LISTO. El costo de mano de obra que guarde aquí es el que `fn_TotalOrden` usará para facturar.

**`fn_HistorialEquipo` (jueves 22).** Función de tabla en línea: se usa como una vista con parámetro. Todas las relaciones después de la orden son 0..1, así que los `LEFT JOIN` no duplican filas:

```sql
CREATE OR ALTER FUNCTION dbo.fn_HistorialEquipo (@numeroSerie VARCHAR(60))
RETURNS TABLE
AS
RETURN
SELECT o.idOrden, o.numeroOrden, o.fechaIngreso, o.estado, o.problemaReportado,
       d.descripcion       AS diagnostico,
       tec.nombreCompleto  AS tecnico,
       r.costoManoObra, r.fechaFin,
       f.serie, f.numero, f.total
FROM dbo.Equipo e
INNER JOIN dbo.OrdenServicio o ON o.idEquipo = e.idEquipo
LEFT JOIN dbo.Diagnostico d    ON d.idOrden = o.idOrden
LEFT JOIN dbo.Usuario tec      ON tec.idUsuario = d.idTecnico
LEFT JOIN dbo.Reparacion r     ON r.idDiagnostico = d.idDiagnostico
LEFT JOIN dbo.Factura f        ON f.idOrden = o.idOrden AND f.estado = 'EMITIDA'
WHERE e.numeroSerie = @numeroSerie;
```

- [ ] Agregarla a `20_vistas_ordenes.sql` y probarla con `SELECT * FROM dbo.fn_HistorialEquipo('SERIE-001') ORDER BY fechaIngreso DESC;` (en pruebas sí se vale `SELECT *`; en reportes no).

### B4 · Reportes 1 a 4 y datos (miércoles 21 – sábado 24)

Archivo `50_reportes_ordenes.sql`. Filtros opcionales con `(@p IS NULL OR col = @p)`; sin `SELECT *` ni `DISTINCT`.

| SP | Parámetros | Columnas clave | Lo que debe poder justificar |
|---|---|---|---|
| `sp_Reporte_01_OrdenesActivas` | `@estado`, `@prioridad`, `@idTecnico` | orden, cliente, equipo, estado, prioridad, técnico, días abierta | Sale de `vw_OrdenesActivas`; LEFT JOIN al técnico porque una orden RECIBIDA aún no lo tiene. Usa el índice IX1 |
| `sp_Reporte_02_HistorialCliente` | `@idCliente` (o `@nit`) | orden, equipo, fecha, estado, diagnóstico, total facturado | LEFT JOIN a Diagnóstico y Factura: una orden recién recibida no tiene ninguno y debe aparecer igual |
| `sp_Reporte_03_HistorialEquipo` | `@numeroSerie` | lo que devuelve `fn_HistorialEquipo` | Busca por serie con el índice que crea el UNIQUE; ordenado por fecha descendente |
| `sp_Reporte_04_ProductividadTecnico` | `@idTecnico`, `@fechaInicio`, `@fechaFin` | técnico, diagnósticos, reparaciones finalizadas, horas registradas, mano de obra | 6 tablas; LEFT JOIN a Reparación (diagnósticos no autorizados). Si junta actividades y repuestos en el mismo SELECT se multiplican filas: sume las horas en una subconsulta |

- [ ] El reporte 4 agrupa (`GROUP BY` técnico). Use `COUNT(DISTINCT d.idDiagnostico)` solo si es necesario y explíquelo; es más limpio sumar horas en una subconsulta `(SELECT SUM(horas) FROM ActividadReparacion …)` para no multiplicar filas.
- [ ] Endpoints de facturación, pagos, entrega, dashboard y reportes (consumen los SP de A y C, con el mismo patrón).
- [ ] `83_datos_ordenes.sql`: 60+ órdenes por SP en todos los estados (ver el comentario del archivo y los escenarios de C4).

### B5 · Pruebas, documentos y defensa (domingo 25 – viernes 30)

**Sus pruebas** (script en `database/pruebas/` + captura):

| Prueba | Qué ejecutar | Qué debe verse |
|---|---|---|
| T01 | Registrar cliente y equipo desde la app | Fila en `Cliente` y `Equipo`; NIT duplicado → 409 |
| T02 | `sp_RegistrarOrdenServicio` | Orden RECIBIDA con `numeroOrden` y una fila de historial |
| T03 | `sp_RegistrarDiagnostico` | Diagnóstico guardado, orden en ESPERANDO_AUTORIZACION, dos filas más en el historial |
| T11 | `sp_Reporte_03_HistorialEquipo` con el equipo de 3+ órdenes | Todas sus órdenes, incluso la que no tiene factura |
| Extra | `UPDATE dbo.OrdenServicio SET estado = 'ENTREGADO' WHERE idOrden = <una RECIBIDA>` desde SSMS | Error 51002 del trigger: la regla vale aunque no se use la app (R16) |
| Extra | Diagnosticar con un usuario de Caja desde la app | 403 de la API; y desde SSMS, el `THROW` de rol del SP |

**Documentos a su cargo:**

- [ ] **Manual técnico** (empezar el domingo 25): arquitectura (BD → API → frontend, con el diagrama de la sección 5.2 del plan; el frontend nunca toca la BD), stack y versiones, estructura del repo, configuración (`user-secrets`, variables de entorno, usuario `techcare_app`), catálogo de objetos de BD (una tabla con cada SP, vista, función y trigger: propósito, parámetros, reglas que garantiza), seguridad (hash, JWT, permisos, mínimo privilegio), manejo de errores (rangos de códigos y su traducción a HTTP), despliegue.
- [ ] **Plan de pruebas consolidado** (miércoles 28): juntar las pruebas de los tres con el mismo formato (objetivo, entrada, script, esperado, obtenido, captura).

**Lo que debe poder explicar en la defensa:**

- El trigger `trg_OrdenServicio_Estado` completo: por qué es AFTER y no INSTEAD OF, por qué es *set-based*, cómo obtiene el usuario por `SESSION_CONTEXT`, por qué `UPDATE(estado)`.
- La máquina de estados: cómo agregar un estado nuevo (dos INSERT en catálogos, cero código).
- `SCOPE_IDENTITY` frente a `@@IDENTITY` con el ejemplo real del historial.
- Cómo la API evita SQL injection (solo parámetros) y la suplantación (`idUsuario` del token).
- Modificación en vivo típica de su dominio: agregar un filtro `@fechaInicio/@fechaFin` al reporte 1, o una regla nueva en un SP (por ejemplo, no permitir prioridad URGENTE sin fecha estimada). Practíquela el jueves 29.

---

## 6. Paso a paso de A · Frontend

A tiene dos frentes: la aplicación que verá el profesor y el dominio de **facturación, pagos y entrega** en la BD, que incluye una de las tres transacciones estrella (`sp_RegistrarPago`) y el reporte más difícil (trazabilidad). **No espere a la API:** hasta el martes 20 trabaje con datos simulados que tengan la misma forma que el contrato de B (tabla en B2).

### A1 · Preparación (lunes 19)

- [ ] Instalar Node.js 22 LTS, Git, VS Code con la extensión *Vue (Official)*, SSMS 21 (o VS Code + MSSQL en Mac), `sqlcmd` y Tailscale (o mandar su IP a C si usan Azure).
- [ ] Crear su base personal `TechCare_Front` (1.4).
- [ ] Revisar el modelo antes del congelamiento (1.5): secciones 8 y 9 de `02_tablas.sql` y las tres funciones que va a defender. Si algo no le cuadra, dígalo hoy.

### A2 · La aplicación Nuxt paso a paso (lunes 19 – sábado 24)

**Proyecto:**

```powershell
npm create nuxt@latest frontend      # plantilla mínima, npm, inicializar git: no (ya existe el repo)
cd frontend
npx nuxi module add ui               # Nuxt UI: tablas, formularios, modales, toasts
npx nuxi module add pinia
npm i zod                            # validación de formularios
npm run dev                          # http://localhost:3000
```

`nuxt.config.ts` (dejen el `compatibilityDate` que generó el asistente):

```ts
export default defineNuxtConfig({
  ssr: false,                                   // SPA: login con JWT sin complicaciones
  modules: ['@nuxt/ui', '@pinia/nuxt'],
  css: ['~/assets/css/main.css'],
  runtimeConfig: { public: { apiBase: '' } },   // se llena con NUXT_PUBLIC_API_BASE en .env
})
```

`frontend/.env` (no va a git):

```text
NUXT_PUBLIC_API_BASE=https://localhost:7xxx/api
```

`app/assets/css/main.css`:

```css
@import "tailwindcss";
@import "@nuxt/ui";
```

`app/app.vue`:

```vue
<template>
  <UApp>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
```

**Sesión, llamadas a la API y permisos:**

- [ ] Store `app/stores/auth.ts` (Pinia): `token`, `usuario` (`idUsuario`, `nombreCompleto`, `roles`, `permisos`), acción `login` que llama `POST /auth/login` y guarda en `sessionStorage`, acción `logout`, y un getter `puede(permiso)`:

  ```ts
  type Usuario = { idUsuario: number; nombreCompleto: string; roles: string[]; permisos: string[] }

  export const useAuthStore = defineStore('auth', {
    state: () => ({ token: null as string | null, usuario: null as Usuario | null }),
    getters: {
      puede: (s) => (permiso: string) => s.usuario?.permisos.includes(permiso) ?? false,
    },
    actions: {
      async login(username: string, password: string) {
        const { public: cfg } = useRuntimeConfig()
        const r = await $fetch<{ token: string; usuario: Usuario }>('/auth/login', {
          baseURL: cfg.apiBase, method: 'POST', body: { username, password },
        })
        this.token = r.token
        this.usuario = r.usuario
        try { sessionStorage.setItem('tc_sesion', JSON.stringify(r)) } catch { /* modo privado */ }
      },
      restaurar() {
        try {
          const s = sessionStorage.getItem('tc_sesion')
          if (s) { const r = JSON.parse(s); this.token = r.token; this.usuario = r.usuario }
        } catch { /* sin almacenamiento: se pide login */ }
      },
      logout() {
        this.token = null
        this.usuario = null
        try { sessionStorage.removeItem('tc_sesion') } catch { /* nada */ }
        navigateTo('/login')
      },
    },
  })
  ```

- [ ] Composable `app/composables/useApi.ts`: todas las llamadas pasan por aquí; agrega el token y muestra tal cual el error de negocio que mandó la BD:

  ```ts
  export const useApi = () => {
    const config = useRuntimeConfig()
    const auth = useAuthStore()
    const toast = useToast()
    return $fetch.create({
      baseURL: config.public.apiBase,
      onRequest({ options }) {
        if (auth.token) {
          const headers = new Headers(options.headers)
          headers.set('Authorization', `Bearer ${auth.token}`)
          options.headers = headers
        }
      },
      onResponseError({ response }) {
        if (response.status === 401) return auth.logout()
        // 409/422: el mensaje viene del THROW del SP (p. ej. "El pago excede el saldo pendiente…")
        toast.add({ title: 'No se pudo completar', description: response._data?.error ?? 'Error inesperado', color: 'error' })
      },
    })
  }
  ```

- [ ] Middleware `app/middleware/auth.global.ts`: sin token → `/login`; si la página declara `definePageMeta({ permiso: 'ORDEN_CREAR' })` y el usuario no lo tiene → `/`. El menú lateral (`app/layouts/default.vue`) se filtra con el mismo `puede()`. Esto es comodidad visual; la seguridad real la hacen la API (políticas) y la BD (`fn_UsuarioTieneRol`):

  ```ts
  export default defineNuxtRouteMiddleware((to) => {
    const auth = useAuthStore()
    if (!auth.token) auth.restaurar()
    if (to.path !== '/login' && !auth.token) return navigateTo('/login')

    const permiso = to.meta.permiso as string | undefined
    if (permiso && !auth.puede(permiso)) return navigateTo('/')
  })
  ```

- [ ] Validación en el cliente con `UForm` + esquemas zod (campos obligatorios, montos > 0, email válido). La API y la BD vuelven a validar: si alguien pregunta, son tres capas. Ejemplo, el formulario de pago (`app/components/FormPago.vue`, lo usan la caja y la pestaña de pagos):

  ```vue
  <script setup lang="ts">
  import { z } from 'zod'

  const props = defineProps<{ idFactura: number; saldo: number }>()
  const emit = defineEmits<{ pagado: [] }>()
  const api = useApi()

  const schema = z.object({
    idMetodoPago: z.number().int().positive('Elija un método de pago'),
    monto: z.number().positive('Debe ser mayor que 0').max(props.saldo, 'No puede exceder el saldo'),
    referencia: z.string().max(60).optional(),
  })
  const state = reactive({ idMetodoPago: undefined as number | undefined, monto: undefined as number | undefined, referencia: '' })

  async function onSubmit() {
    await api(`/facturas/${props.idFactura}/pagos`, { method: 'POST', body: state })
    emit('pagado')
  }
  </script>
  ```

  El `<template>` usa `UForm` con `:schema` y `:state`, `UFormField` y los inputs de Nuxt UI; consulten https://ui.nuxt.com para la API exacta de la versión instalada.

**Pantallas (orden de construcción):**

| Ruta | Qué hace | Endpoint principal | Permiso | Cuándo |
|---|---|---|---|---|
| `/login` | Usuario y contraseña | `POST /auth/login` | — | Lun 19 |
| `/` | Dashboard: contadores + órdenes recientes | `GET /dashboard` | REPORTE_VER | Vie 23 |
| `/clientes`, `/clientes/[id]` | Lista, búsqueda, alta y edición; equipos e historial del cliente | `/clientes`, `/equipos`, reporte 2 | CLIENTE_GESTIONAR | Lun 19 – Mar 20 |
| `/ordenes/nueva` | Buscar cliente → elegir o crear equipo → problema y prioridad | `POST /ordenes` | ORDEN_CREAR | Mar 20 |
| `/ordenes` | Órdenes activas con filtros por estado, prioridad y técnico | `GET /ordenes` | REPORTE_VER | Mar 20 |
| `/ordenes/[id]` | **Pantalla central** con pestañas: Resumen e historial · Diagnóstico · Reparación (actividades y repuestos) · Factura y pagos · Entrega. Cada botón aparece solo si el estado y el permiso lo permiten | endpoints de órdenes, reparaciones, factura, pagos, entrega | varios | Mié 21 – Sáb 24 |
| `/inventario`, `/inventario/kardex` | Existencias por bodega con etiqueta de estado de stock; movimientos | `/inventario`, reporte 9 | REPORTE_VER | Jue 22 (con C) |
| `/compras`, `/compras/nueva` | Compras; alta con líneas dinámicas (viajan como TVP); botón Recibir | `/compras` | COMPRA_* | Jue 22 (C) |
| `/caja` | Facturas con saldo; registrar pago desde la lista | `GET /facturas?conSaldo=true` | PAGO_REGISTRAR | Sáb 24 |
| `/reportes`, `/reportes/[n]` | Índice de los 12 reportes con sus filtros | `GET /reportes/{n}` | REPORTE_VER | Dom 25 – Lun 26 |
| `/admin/usuarios`, `/admin/catalogos` | Usuarios y roles; repuestos, proveedores, bodegas | CRUD | USUARIO_GESTIONAR / CATALOGO_GESTIONAR | Lun 26 |

Consejos para la pantalla central: muestren siempre arriba el número de orden, el estado (con color) y el saldo; y después de cada acción **vuelvan a pedir la orden a la API** en lugar de modificar el estado en el cliente. Así lo que ven es exactamente lo que quedó en la BD.

Los procesos de la sección 6.2 del enunciado **no son formularios CRUD**: cada uno es una acción con su botón ("Registrar diagnóstico", "Iniciar reparación", "Agregar repuesto", "Facturar", "Registrar pago", "Entregar") que llama a un solo endpoint (un SP).

**Componente común de reportes** (`app/components/ReporteTabla.vue`): recibe el número de reporte, las columnas y los filtros (fechas, cliente, técnico, bodega…), llama `GET /reportes/{n}` con los filtros como query y muestra un `UTable`. Cada dueño agrega sus reportes con una línea de configuración en `app/utils/reportes.ts`, sin escribir otra página. Así B y C configuran sus reportes 1–9 sin tocar las pantallas de A.

### A3 · Dominio de BD: facturación, pagos y entrega (martes 20 – sábado 24)

Trabaja en `TechCare_Front` y en `22_vistas_facturacion.sql`, `43_sp_facturacion.sql` y `52_reportes_facturacion.sql`. Códigos de error 50300–50399. Defiende `fn_TotalPagado`, `fn_SaldoFactura` y `fn_TotalOrden`: léalas hoy y entienda por qué el saldo **no** se guarda.

Para probar sus SP necesita una orden en estado LISTO con reparación y repuestos. Mientras B termina sus SP, créela en su base personal con INSERT directos (solo en su base, solo para probar) o use los datos de prueba en cuanto existan.

**`sp_RegistrarPago` (martes 20 – miércoles 21): transacción estrella (R12, T09, T10).** Ya está escrito en `43_sp_facturacion.sql`:

```sql
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPago
    @idFactura     INT,
    @idMetodoPago  INT,
    @monto         DECIMAL(12,2),
    @idUsuario     INT,
    @referencia    VARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'CAJA') = 0
        THROW 50301, 'El usuario no tiene rol de caja.', 1;

    IF @monto IS NULL OR @monto <= 0
        THROW 50302, 'El monto debe ser mayor que cero.', 1;

    DECLARE @requiereRef BIT;
    SELECT @requiereRef = mp.requiereReferencia
    FROM dbo.MetodoPago mp
    WHERE mp.idMetodoPago = @idMetodoPago AND mp.estado = 'ACTIVO';

    IF @requiereRef IS NULL
        THROW 50303, 'Método de pago inválido o inactivo.', 1;
    IF @requiereRef = 1 AND NULLIF(LTRIM(RTRIM(@referencia)), '') IS NULL
        THROW 50304, 'Este método de pago requiere número de referencia.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(10);

        -- Bloquea la factura: un segundo cajero espera aquí y después ve el saldo ya actualizado
        SELECT @estado = f.estado
        FROM dbo.Factura f WITH (UPDLOCK, HOLDLOCK)
        WHERE f.idFactura = @idFactura;

        IF @estado IS NULL      THROW 50305, 'La factura no existe.', 1;
        IF @estado <> 'EMITIDA' THROW 50306, 'La factura está anulada.', 1;

        DECLARE @saldo DECIMAL(12,2) = dbo.fn_SaldoFactura(@idFactura);

        IF @saldo = 0      THROW 50307, 'La factura ya está pagada.', 1;
        IF @monto > @saldo THROW 50308, 'El pago excede el saldo pendiente de la factura (R12).', 1;

        INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, referencia, idUsuarioCaja)
        VALUES (@idFactura, @idMetodoPago, @monto, @referencia, @idUsuario);

        DECLARE @idPago INT = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;

        SELECT @idPago AS idPago, @saldo - @monto AS saldoRestante;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
```

- [ ] Probar: pago parcial (el saldo baja), segundo pago que completa, tercer pago (error 50307), pago mayor al saldo (error 50308), TARJETA sin referencia (error 50304).
- [ ] Demo de concurrencia para la defensa: en una ventana de SSMS ejecuten `BEGIN TRAN; SELECT * FROM dbo.Factura WITH (UPDLOCK) WHERE idFactura = 1;` sin confirmar; en otra, `EXEC dbo.sp_RegistrarPago …` sobre la misma factura: se queda esperando. `ROLLBACK` en la primera y la segunda continúa. **Háganlo en su base personal**, nunca en la compartida.

**`sp_FacturarOrden` (miércoles 21 – jueves 22) (R11, T08)**

- [ ] Firma: `@idOrden, @idUsuario, @nitFacturacion = NULL, @nombreFacturacion = NULL, @direccionFacturacion = NULL`.
- [ ] Antes de la transacción: rol CAJA. Dentro: leer la orden con `UPDLOCK, HOLDLOCK`; debe estar en LISTO y sin factura previa (además, `UQ_Factura_Orden` lo impide aunque falle su validación).
- [ ] NIT, nombre y dirección por defecto: los del cliente (`OrdenServicio → Equipo → Cliente`) con `ISNULL(@nitFacturacion, c.nit)`.
- [ ] `@subtotal = dbo.fn_TotalOrden(@idOrden)`; si es 0, `THROW` ("no hay montos que facturar; entregue la orden sin factura"). `@impuesto = ROUND(@subtotal * 0.12, 2)`; `@total = @subtotal + @impuesto` (el CHECK `CK_Factura_Total` exige que cuadre exacto).
- [ ] `INSERT Factura` y luego las líneas. La parte con truco: numerar las líneas de repuestos con `ROW_NUMBER()` a continuación de la mano de obra:

  ```sql
  -- Línea 1: mano de obra (si hubo reparación con costo)
  INSERT INTO dbo.DetalleFactura (idFactura, numeroLinea, tipoLinea, descripcion, cantidad, precioUnitario)
  SELECT @idFactura, 1, 'MANO_OBRA', N'Mano de obra ' + o.numeroOrden, 1, r.costoManoObra
  FROM dbo.OrdenServicio o
  INNER JOIN dbo.Diagnostico d ON d.idOrden = o.idOrden
  INNER JOIN dbo.Reparacion r  ON r.idDiagnostico = d.idDiagnostico
  WHERE o.idOrden = @idOrden AND r.estado = 'FINALIZADA' AND r.costoManoObra > 0;

  DECLARE @base SMALLINT = (SELECT COUNT(*) FROM dbo.DetalleFactura WHERE idFactura = @idFactura);

  -- Una línea por repuesto aplicado, con su precio HISTÓRICO (R09)
  INSERT INTO dbo.DetalleFactura
      (idFactura, numeroLinea, tipoLinea, descripcion, cantidad, precioUnitario, idDetalleRepuesto)
  SELECT @idFactura,
         @base + ROW_NUMBER() OVER (ORDER BY dr.idDetalleRepuesto),
         'REPUESTO', rp.nombre, dr.cantidad, dr.precioUnitario, dr.idDetalleRepuesto
  FROM dbo.Diagnostico d
  INNER JOIN dbo.Reparacion r       ON r.idDiagnostico = d.idDiagnostico
  INNER JOIN dbo.DetalleRepuesto dr ON dr.idReparacion = r.idReparacion AND dr.estado = 'APLICADO'
  INNER JOIN dbo.Repuesto rp        ON rp.idRepuesto = dr.idRepuesto
  WHERE d.idOrden = @idOrden;

  -- Verificación defensiva: las líneas deben sumar exactamente el subtotal
  IF (SELECT SUM(subtotalLinea) FROM dbo.DetalleFactura WHERE idFactura = @idFactura) <> @subtotal
      THROW 50310, 'Las líneas de la factura no cuadran con el total de la orden.', 1;
  ```

- [ ] Devolver `idFactura, serie, numero, total`. Probar: facturar (T08), facturar otra vez (error), facturar una orden en REPARACION (error).

**`sp_AnularPago` y `sp_EntregarOrden` (viernes 23)**

- [ ] **`sp_AnularPago`** (`@idPago, @idUsuario, @motivo`): motivo obligatorio; pago APLICADO; no permitir si la orden ya fue ENTREGADA (quedaría saldo después de entregar). `UPDATE Pago SET estado = 'ANULADO', motivoAnulacion = @motivo`. Nunca `DELETE` (R14).
- [ ] **`sp_EntregarOrden`** (`@idOrden, @idUsuarioEntrega, @nombreRecibe, @documentoRecibe = NULL, @observaciones = NULL`): orden en LISTO con `UPDLOCK`; si hubo reparación FINALIZADA, exigir factura EMITIDA con `fn_SaldoFactura = 0`; `INSERT Entrega`; `sp_EstablecerContexto` + `UPDATE … SET estado = 'ENTREGADO'`. El trigger vuelve a verificar las mismas reglas: si alguien intenta saltarse el SP desde SSMS, igual falla (R16).

**Vistas (viernes 23), archivo 22**

- [ ] `vw_FacturasSaldo`: factura + cliente (vía orden y equipo) + `dbo.fn_TotalPagado(f.idFactura) AS totalPagado` + `dbo.fn_SaldoFactura(f.idFactura) AS saldo` + `estadoPago` con `CASE`. **No** hagan JOIN con `Pago` aquí: una factura con 3 pagos saldría 3 veces.
- [ ] `vw_DashboardResumen`: una sola fila con subconsultas `(SELECT COUNT(*) …)` para órdenes abiertas, en diagnóstico, en reparación, listas para entregar, facturas con saldo y repuestos bajo mínimo (este último sobre `vw_InventarioActual` de C). La "actividad reciente" que pide el enunciado (6.3) se muestra con las últimas órdenes y los últimos movimientos.
- [ ] `84_datos_facturacion.sql`: 30+ facturas y 40+ pagos por SP (ver el comentario del archivo y los escenarios de C4).

### A4 · Reportes 10, 11 y 12 (domingo 25 – lunes 26)

Archivo `52_reportes_facturacion.sql`.

- [ ] **`sp_Reporte_10_FacturasSaldo`** (`@soloConSaldo BIT = 1`, `@idCliente`, `@fechaInicio`, `@fechaFin`): dos result sets. El primero, una fila por factura desde `vw_FacturasSaldo`. El segundo, el detalle de pagos (`Pago` + `MetodoPago` + usuario de caja) de esas mismas facturas. Si en la pantalla quieren ver facturas sin ningún pago, ese es su **LEFT JOIN necesario**: `Factura LEFT JOIN Pago`.
- [ ] **`sp_Reporte_11_IngresosPeriodo`** (`@fechaInicio`, `@fechaFin`): separa mano de obra y repuestos gracias a `DetalleFactura.tipoLinea`. Usa el índice IX8. El filtro "hasta el día siguiente" incluye todo el último día aunque la columna tenga hora:

  ```sql
  SELECT YEAR(f.fechaEmision)  AS anio,
         MONTH(f.fechaEmision) AS mes,
         COUNT(DISTINCT f.idFactura) AS facturas,
         SUM(CASE WHEN df.tipoLinea = 'MANO_OBRA' THEN df.subtotalLinea ELSE 0 END) AS ingresoManoObra,
         SUM(CASE WHEN df.tipoLinea = 'REPUESTO'  THEN df.subtotalLinea ELSE 0 END) AS ingresoRepuestos,
         SUM(df.subtotalLinea) AS subtotal
  FROM dbo.Factura f
  INNER JOIN dbo.DetalleFactura df ON df.idFactura = f.idFactura
  WHERE f.estado = 'EMITIDA'
    AND f.fechaEmision >= @fechaInicio
    AND f.fechaEmision <  DATEADD(DAY, 1, @fechaFin)
  GROUP BY YEAR(f.fechaEmision), MONTH(f.fechaEmision)
  ORDER BY anio, mes;
  ```

  (Aquí `COUNT(DISTINCT f.idFactura)` es legítimo: cuenta facturas dentro de un agrupamiento por líneas, no oculta duplicados de un JOIN mal hecho. Si se lo preguntan, esa es la diferencia.)

- [ ] **`sp_Reporte_12_Trazabilidad`** (`@idOrden`): el reporte más difícil y el que más luce en la defensa. Una orden tiene varios repuestos **y** varios pagos; unidos en un solo SELECT, cada repuesto se repite por cada pago (producto cartesiano) y los totales salen inflados. La solución son **cinco result sets**, en este orden:
  1. Encabezado (una fila): orden, cliente, equipo, recepcionista, fecha de ingreso, diagnóstico, técnico, reparación, factura, total pagado, saldo, entrega. Todo con `LEFT JOIN` porque cada etapa puede no existir aún. Son 10 o más tablas sin duplicar filas, porque después de la orden todas las relaciones son 0..1.
  2. Repuestos usados: bodega, repuesto, cantidad, precio histórico, técnico.
  3. Movimientos de inventario de esos repuestos (por `idDetalleRepuesto`).
  4. Pagos: fecha, método, monto, referencia, cajero, estado.
  5. Historial de estados: anterior, nuevo, fecha, usuario, observación.
- [ ] Pantalla `/ordenes/[id]/trazabilidad` con una sección por result set (B lo lee con `QueryMultipleAsync`). Agreguen un botón de imprimir (`window.print()` y una hoja de estilos de impresión sencilla).

### A5 · Pruebas, manual de usuario y defensa (domingo 25 – viernes 30)

**Sus pruebas** (script en `database/pruebas/` + captura de la pantalla):

| Prueba | Qué ejecutar | Qué debe verse |
|---|---|---|
| T08 | Facturar una orden LISTO desde `/ordenes/[id]` | Factura con líneas de mano de obra y repuestos; total = subtotal + 12 %; segundo intento → error |
| T09 | Dos pagos parciales y uno que completa | El saldo baja en cada pago y termina en 0; el estado pasa a PAGADA |
| T10 | Pago mayor al saldo | Mensaje del SP en pantalla; ningún pago insertado |
| T12 | Reporte de trazabilidad de una orden ENTREGADA | Las cinco secciones completas y consistentes |
| Extra | Intentar entregar con saldo pendiente desde SSMS (`UPDATE … SET estado = 'ENTREGADO'`) | Error 51003 del trigger |

**Manual de usuario (martes 27 – miércoles 28):**

- [ ] Una sección por rol (Recepción, Técnico, Bodega, Caja, Administrador) con sus tareas paso a paso y una captura por pantalla. El enunciado exige al menos: ingreso, diagnóstico, reparación, compra, facturación, pago y reportes.
- [ ] El flujo completo de una orden, de la recepción a la entrega, contado como una historia con un cliente de ejemplo.
- [ ] Los mensajes de error más comunes y qué hacer ("Existencia insuficiente", "El pago excede el saldo"…).
- [ ] Usuarios y contraseñas de prueba (los que genera el comando de B).

**Lo que debe poder explicar en la defensa:**

- `sp_RegistrarPago` línea por línea y la demo de las dos ventanas.
- Por qué el total de la factura se guarda y el saldo no (documento fiscal congelado frente a un valor que cambia con cada pago).
- Por qué `DetalleFactura` copia el precio y no lo lee de `Repuesto` (R09, prueba T14 de C).
- Cómo `UQ_Factura_Orden` implementa R11 sin una sola línea de código.
- El producto cartesiano del reporte 12 y por qué `DISTINCT` no lo arregla.
- Modificación en vivo típica de su dominio: cambiar la tasa de impuesto, agregar un método de pago, o mostrar en `vw_FacturasSaldo` los días desde la emisión. Practíquela el jueves 29.

---

## 7. Cierre común: 27, 28, 29 y 30 de octubre

### Martes 27: prueba en limpio (los 3)

El enunciado exige que el sistema se levante "desde una computadora limpia". Se prueba de verdad:

- [ ] **C**, en una máquina o contenedor sin nada previo: SQL Server vacío → `./reconstruir.ps1 -Servidor localhost -Usuario sa` → backend → frontend, **siguiendo solo el README**. Cada paso que no esté escrito se agrega al README.
- [ ] **B** ejecuta T01–T03 y T11; **C** T04–T07, T13 y T14; **A** T08–T10 y T12. Cada prueba con resultado esperado, resultado obtenido y captura.
- [ ] Revisar las condiciones de aceptación de la sección 11 del enunciado, punto por punto, con evidencia.

### Miércoles 28: documentos

| Entregable | Responsable | Contenido mínimo |
|---|---|---|
| 01 Código fuente | C | Repo con tag `v1.0`; zip sin `node_modules`, `bin` ni `obj` |
| 02 Script maestro | C | `build/TechCare_Master.sql` generado desde `main` |
| 03 Datos de prueba | C (con aportes de A y B) | `build/TechCare_DatosPrueba.sql` |
| 04 Diagrama ER | C | Exportado desde la BD final (lunes 26) |
| 05 Normalización | C | 1FN, 2FN y 3FN con ejemplos del modelo propio |
| 06 Manual técnico | B | Estructura de B5 |
| 07 Manual de usuario | A | Estructura de A5 |
| 08 Plan y evidencia de pruebas | B (consolida) | T01–T14 + pruebas de integridad (CHECK, FK, UNIQUE, trigger) con esperado y obtenido |
| 09 README de ejecución | C | Pasos exactos verificados el martes |

### Jueves 29: congelar y ensayar

- [ ] 12:00: tag `v1.0` en `main`. Después de eso, solo correcciones de errores con PR.
- [ ] Laptop de demostración con la base local (C5), backend y frontend; probar **sin internet**.
- [ ] Copia del repo y del `.bak` en dos lugares (USB + nube).
- [ ] **Ensayo de defensa (2 h):** cada uno explica en voz alta el SQL de **otro** integrante (un SP, una vista, un reporte y un trigger), y los otros dos hacen las preguntas de la sección 9.3 del plan. Practiquen una modificación en vivo de cada dominio.

### Viernes 30: entrega

- [ ] Subir los 9 entregables a CANVAS según lo publique el docente.
- [ ] Llegar con la laptop de demostración cargada, el sistema levantado y las consultas de demostración abiertas en SSMS: rollback (T07), pago excesivo (T10), `UPDATE` directo de stock rechazado con `techcare_app`, `DELETE` de un movimiento (R14) y transición de estado inválida (R16).

---

### Fuentes

- [Azure SQL Database free offer — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer)
- [Azure for Students — Microsoft](https://azure.microsoft.com/en-us/free/students)
