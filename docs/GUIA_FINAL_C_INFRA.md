# TechCare — Flujo final y guía de C para dejar la BD lista hoy

> Esta guía **reemplaza** las partes de infraestructura de `GUIA_PASO_A_PASO.md` donde no coincidan: las bases personales ahora viven en la laptop de cada uno (no en la VM) y la base compartida vive en Azure SQL Database. Todo lo demás de esa guía (roles, SP, reportes, pruebas, calendario) sigue igual.
>
> Fecha: lunes 19 de octubre de 2026. Entrega: viernes 30.

**Resumen:**

- **Una sola base compartida en Azure:** `TechCare`.
- **Una base local por integrante** en su laptop, para probar antes de integrar.
- **La presentación usa una base local en la laptop de demostración**; las otras dos computadoras se conectan a ella por red local.
- **La web pública es gratis:** el frontend en Cloudflare Pages, la API en Azure App Service (plan gratuito) y la base en Azure SQL.

---

## 1. ¿Estás en lo correcto?

Casi todo, sí. Hay tres ajustes importantes:

| Lo que planteaste | Veredicto | Ajuste |
|---|---|---|
| En Azure vive 1 base (`TechCare`) para los 3 | ✔ Correcto | Es la base de **integración**: el backend de los tres apunta ahí |
| Cada uno entra con su propio usuario y permisos | ✔ Correcto | Mínimo privilegio también para ustedes: pueden crear y cambiar SP, vistas, funciones y triggers, pero **no tablas ni índices**; eso lo bloquea la base misma (sección 3) |
| Un usuario para el backend que acceda a los SP | ✔ Correcto | `techcare_app`: ejecuta SP y lee; escribe solo en catálogos; **no puede** tocar inventario, facturas ni pagos directamente |
| Es la base "real final" | ⚠ Ajuste | La versión "real final" es **el script maestro en git**, no la base. La base de Azure es una copia que debe poder reconstruirse en cualquier momento desde `main`. El profesor evalúa el script, el modelo y la demo; si la base de Azure se borrara hoy, en 5 minutos estaría igual |
| En ella ejecutamos las queries cuando estamos seguros | ⚠ Ajuste | No se ejecutan "queries sueltas": se despliega **el archivo de su dominio desde `main`**, después del PR y del check `db-build`. Los datos se cargan solo con los scripts `80`–`85`; nunca a mano. Las pruebas se hacen dentro de una transacción con `ROLLBACK` |
| Cada uno tiene una base local para pruebas | ✔ Correcto | SQL Server 2022 Developer (gratis) instalado en su laptop, con `TechCare_Front`, `TechCare_Back` o `TechCare_Infra` |
| Para la presentación usamos la base local de la laptop de demostración | ✔ Correcto | Y las otras dos computadoras se conectan a esa laptop por red local para mostrar roles distintos (sección 8) |
| "Crear la VM" | ⚠ Ajuste | **Azure SQL Database no es una VM:** es una base administrada (PaaS). No hay sistema operativo que instalar ni que mantener. No creen una VM en Azure: cuesta crédito y no hace falta. La VM que ya tienen queda como plan B |

---

## 2. El flujo final

```text
                         ┌────────────────────────── git (GitHub) ──────────────────────────┐
                         │  database/*.sql  ·  backend/  ·  frontend/  ·  CI: db-build      │
                         └────────▲───────────────────────────────────────────┬─────────────┘
                                  │ PR + revisión cruzada                     │ merge a main
                                  │                                           ▼
  ┌────────────────────┐   ┌──────┴────────────────────┐        ┌─────────────────────────────────┐
  │ Laptop A           │   │ Laptop B                  │        │ Azure SQL Database              │
  │ SQL local          │   │ SQL local                 │        │ TechCare (compartida)           │
  │ TechCare_Front     │   │ TechCare_Back             │  ───►  │ dev_front · dev_back · dev_infra│
  │ (pruebas)          │   │ (pruebas)                 │ desp.  │ techcare_app (backend)          │
  └────────────────────┘   └───────────────────────────┘ desde  │ tcadmin (solo C)                │
  ┌────────────────────┐                                 main   └───────────────┬─────────────────┘
  │ Laptop C           │                                                        │
  │ SQL local          │      Web pública (opcional, sección 7):                 │
  │ TechCare_Infra     │      Cloudflare Pages ──► App Service F1 (API) ────────┘
  └────────────────────┘
  Presentación (sección 8): laptop de demostración con SQL + API + web locales; las otras 2 laptops entran por red local.
```

| Base | Dónde | Quién escribe | Para qué |
|---|---|---|---|
| `TechCare_Front` / `_Back` / `_Infra` | Laptop de cada uno | Su dueño, libremente | Escribir, romper y probar antes de integrar. Funciona sin internet |
| `TechCare` | Azure SQL Database | Archivos de `main`, cada uno con su usuario | Integración: el backend de los tres apunta aquí. Siempre igual a `main` |
| `TechCare` | Laptop de demostración | C, el jueves 29 | Presentación del 30, sin depender de internet |
| (Plan B) | VM + Tailscale | Nadie, salvo emergencia | Si Azure falla, `reconstruir.ps1` la levanta en 15 minutos |

**Regla única:** lo que entra a Azure es **un archivo de `main`**, desplegado por su dueño. Las tablas solo cambian cuando C reconstruye (ventanas 13:00 y 21:00, avisando antes).

---

## 3. Usuarios y permisos en Azure

| Usuario | Quién | Puede | No puede |
|---|---|---|---|
| `tcadmin` | Solo C | Todo: reconstruir, firewall, crear usuarios | — (se usa solo para administrar, nunca en la app) |
| `dev_infra` | C | Leer y escribir datos; ejecutar; **crear y cambiar SP, vistas, funciones y triggers**; ver planes de ejecución y bloqueos | Crear o cambiar tablas, índices o tipos; hacer `DROP`; dar permisos |
| `dev_back` | B | Lo mismo que `dev_infra` | Lo mismo que `dev_infra` |
| `dev_front` | A | Lo mismo que `dev_infra` | Lo mismo que `dev_infra` |
| `techcare_app` | El backend | Ejecutar SP, leer, escribir en catálogos (clientes, equipos, repuestos…) y en `Inventario.stockMinimo` | Escribir en órdenes, inventario (existencia), compras, facturas, pagos o movimientos: eso solo pasa por los SP |

Cómo se garantiza:

- `91_seguridad_azure.sql` crea dos roles: `rol_desarrollador` (lectura, escritura, ejecución y DDL) y `rol_app` (ejecución, lectura y los `DENY` sobre las tablas transaccionales).
- `92_auditoria_ddl.sql` instala un trigger de base de datos. Si quien ejecuta no es `db_owner`, solo deja pasar `CREATE/ALTER` de procedimientos, funciones, vistas y triggers; todo lo demás lo rechaza con el error **51090**. Además registra en `dbo.AuditoriaDDL` quién cambió qué y cuándo.
- `crear_usuarios_azure.ps1` crea los usuarios **una sola vez**, con contraseñas fuertes generadas en el momento, y las guarda en `infra/credenciales_azure.txt`, que está en `.gitignore`. Las contraseñas nunca pasan por git.

En la defensa esto vale puntos: "el backend no puede modificar el stock directamente; solo los procedimientos pueden, y ni siquiera nosotros podemos alterar una tabla sin reconstruir".

---

## 4. Hoy: lo que hace C, paso a paso

Tiempo total: unas 3 horas. Meta: **antes de las 18:00, A y B se conectan a `TechCare` en Azure con su propio usuario**. A las 20:00 hacen la revisión del núcleo y a las 22:00 queda congelado.

### Paso 0 · Antes de empezar (5 min)

- [ ] Laptop con Windows 10/11 y permisos de administrador.
- [ ] Correo de la universidad a mano (para Azure for Students).
- [ ] El zip `techcare-database.zip` descomprimido en `C:\src\techcare` (o el repo ya clonado).

### Paso 1 · Herramientas en su laptop (20 min)

```powershell
winget install Git.Git
winget install Microsoft.PowerShell
winget install sqlcmd
winget install Microsoft.AzureCLI          # para la web pública (sección 7) y el firewall por consola
winget install dbeaver.dbeaver
```

Además, instale **SSMS 21** (instalador de Microsoft). Cierre y abra la terminal (PowerShell 7) y verifique:

```powershell
git --version; pwsh --version; sqlcmd --version; az --version
```

### Paso 2 · SQL Server local y su base personal (25 min)

1. Descargue **SQL Server 2022 Developer** (gratis) del sitio de Microsoft → elija **Basic**. Instala el motor con autenticación de Windows; para esta guía basta.
2. Construya su base personal con autenticación de Windows:

   ```powershell
   cd C:\src\techcare\database
   ./reconstruir.ps1 -Servidor localhost -Integrada -Db TechCare_Infra
   ```

3. Si falla, **léalo con calma**: el mensaje dice el archivo y la línea. Es la primera vez que los scripts corren en un SQL Server real. Corrija el `.sql`, vuelva a ejecutar (empieza borrando la base, se puede repetir) y anote cada corrección para el commit.
4. Verifique en SSMS (`localhost`, autenticación de Windows):

   ```sql
   USE TechCare_Infra;
   SELECT type_desc, COUNT(*) AS cantidad
   FROM sys.objects
   WHERE is_ms_shipped = 0 AND type IN ('U', 'V', 'P', 'FN', 'IF', 'TR')
   GROUP BY type_desc;
   -- Esperado hoy: 32 tablas (31 + AuditoriaDDL), 1 vista, 6 procedimientos, 4 funciones escalares, 1 trigger
   ```

Esto es lo más importante del día: si el master corre en su laptop, va a correr en Azure.

### Paso 3 · Repositorio en GitHub (25 min)

1. Cree el repo **privado** `techcare` e invite a A y B con permiso *Write*.
2. Suba todo el contenido del zip (`database/`, `docs/`, `.github/`) más el `.gitignore`, la plantilla de PR y `CODEOWNERS` (textos en `GUIA_PASO_A_PASO.md`, sección C2):

   ```powershell
   cd C:\src\techcare
   git init -b main
   git add .
   git commit -m "Núcleo de BD, scripts de build/reconstrucción, CI y guías"
   git remote add origin https://github.com/<organizacion>/techcare.git
   git push -u origin main
   ```

3. *Settings → Branches → Add rule* para `main`: **Require a pull request before merging** (1 aprobación) y **Require status checks to pass** → `db-build`.
4. Abra un PR de prueba que cambie solo un comentario en `database/` y confirme en *Actions* que `db-build` pasa en verde. Es la segunda validación real de los scripts, ahora en un SQL Server limpio de GitHub.

### Paso 4 · Activar Azure for Students (10 min)

1. Entre a https://azure.microsoft.com/free/students → **Start free** → inicie sesión con su cuenta Microsoft y verifique con el **correo de la universidad**. No pide tarjeta.
2. Al terminar, en https://portal.azure.com → *Subscriptions* debe aparecer **Azure for Students** con 100 USD de crédito.
3. Si la verificación con el correo universitario falla, avise al grupo: la alternativa es la VM + Tailscale (sección 9), y el resto de esta guía sigue valiendo.

### Paso 5 · Crear el servidor y la base `TechCare` (15 min)

1. Abra https://aka.ms/azuresqlhub → en *Create a database* elija **Start free**. Debe aparecer el aviso **"Free offer applied!"**.
2. Pestaña **Basics**:

   | Campo | Valor |
   |---|---|
   | Subscription | Azure for Students |
   | Resource group | **Create new** → `rg-techcare` |
   | Database name | `TechCare` |
   | Server | **Create new** → `techcare-grupo5` (debe ser único en Azure; cambien `grupo5` y anótenlo) |
   | Location | La región más cercana disponible (por ejemplo *South Central US* o *East US 2*). No se puede cambiar después |
   | Authentication method | **Use SQL authentication** |
   | Server admin login | `tcadmin` + contraseña fuerte, guardada en su gestor de contraseñas |
   | Behavior when free limit reached | **Continue using database for additional charges** (el excedente sale del crédito de estudiante y la base nunca se pausa antes del 30) |

3. Pestaña **Networking**: *Public endpoint*; **Add current client IP address: Yes**; *Allow Azure services and resources to access this server*: **No** (si publican la API en App Service, se agregan sus IP en la sección 7).
4. Pestaña **Additional settings** → *Collation*: **`Modern_Spanish_CI_AS`**. Solo se puede elegir aquí; si se olvida, hay que borrar la base y crearla de nuevo.
5. *Cost summary* debe mostrar 0 al mes → **Review + create** → **Create**. Tarda unos 3 minutos.

### Paso 6 · Firewall (5 min ahora, 5 min cuando A y B manden su IP)

Su IP ya quedó registrada en el paso 5. Para las de A y B, pídales que entren a https://ifconfig.me y le manden el número. Agréguelas desde la terminal:

```powershell
az login
az sql server firewall-rule create -g rg-techcare -s techcare-grupo5 -n A-casa --start-ip-address <IP-de-A> --end-ip-address <IP-de-A>
az sql server firewall-rule create -g rg-techcare -s techcare-grupo5 -n B-casa --start-ip-address <IP-de-B> --end-ip-address <IP-de-B>
az sql server firewall-rule list -g rg-techcare -s techcare-grupo5 -o table
```

Cuando a alguien le cambie la IP, se ejecuta el mismo comando con `update` en lugar de `create`. Para no depender de usted, puede darles el rol **SQL Server Contributor** sobre `rg-techcare` (*Access control (IAM)* → *Add role assignment*, invitando su correo) y cada uno actualiza su propia regla en el portal.

### Paso 7 · Construir el esquema y los datos en Azure (10 min)

```powershell
cd C:\src\techcare\database
./reconstruir.ps1 -Servidor tcp:techcare-grupo5.database.windows.net,1433 -Usuario tcadmin -Azure
```

Escriba `SI` cuando pregunte. El script ejecuta, en orden: `limpiar_base.sql` → `TechCare_Azure_Master.sql` → datos de prueba → `91_seguridad_azure.sql` → `92_auditoria_ddl.sql`.

La primera conexión puede tardar hasta un minuto si la base estaba en pausa (error 40613): reintente.

### Paso 8 · Crear los usuarios (5 min, una sola vez)

```powershell
./crear_usuarios_azure.ps1 -Servidor tcp:techcare-grupo5.database.windows.net,1433
```

Pide la contraseña de `tcadmin`, crea `techcare_app`, `dev_front`, `dev_back` y `dev_infra` con contraseñas generadas, aplica los permisos y guarda todo en `C:\src\techcare\infra\credenciales_azure.txt` (no va a git).

En las reconstrucciones siguientes **no** se vuelve a ejecutar: los usuarios sobreviven y `reconstruir.ps1 -Azure` reaplica los permisos.

### Paso 9 · Verificar que todo funciona (15 min)

**9.1 Objetos** (conectado como `tcadmin` a `TechCare`, misma consulta del paso 2): los mismos conteos que en su base local.

**9.2 Permisos de un desarrollador.** Conéctese en SSMS como `dev_infra` (*Options → Connection Properties → Connect to database:* `TechCare`) y ejecute:

```sql
-- Debe funcionar: crear y cambiar un SP
CREATE OR ALTER PROCEDURE dbo.sp_PruebaPermisos AS SELECT 1 AS ok;
GO
EXEC dbo.sp_PruebaPermisos;
GO
-- Debe FALLAR con 51090: crear una tabla
CREATE TABLE dbo.Prueba (id INT);
GO
-- Debe FALLAR con 51090: borrar un objeto
DROP PROCEDURE dbo.sp_PruebaPermisos;
GO
```

Después, como `tcadmin`, borre el SP de prueba: `DROP PROCEDURE dbo.sp_PruebaPermisos;`.

**9.3 Permisos del backend.** Conéctese como `techcare_app`:

```sql
SELECT TOP (5) codigo, nombre FROM dbo.Repuesto;                 -- funciona
UPDATE dbo.Inventario SET existencia = 99 WHERE idBodega = 1;     -- FALLA: permiso denegado
EXEC dbo.sp_CambiarEstadoOrden @idOrden = 0, @estadoNuevo = 'X', @idUsuario = 0;  -- funciona la llamada (el SP responde con su error de negocio)
```

**9.4 Auditoría:**

```sql
SELECT TOP (10) fecha, usuarioBD, evento, objeto FROM dbo.AuditoriaDDL ORDER BY idEvento DESC;
```

Si las tres verificaciones salen como se espera, la base compartida está lista.

### Paso 10 · Proteger el crédito (10 min)

- [ ] **Presupuesto con alerta:** portal → *Cost Management* → *Budgets* → **Add**: ámbito `rg-techcare`, monto 20 USD, alerta al 50 % y al 90 % a su correo. Si llega el aviso, se revisa qué quedó encendido.
- [ ] **Alerta de cuota gratuita:** la base `TechCare` → *Monitoring → Alerts* → *Create* → señal **Free amount remaining** menor que 10,000.
- [ ] **Pausa automática:** la base → *Compute + storage* → vCores máximos 1 o 2, y retraso de pausa automática en el mínimo que permita el portal.
- [ ] **Regla del equipo:** cerrar SSMS y detener el backend al terminar. Una conexión abierta mantiene la base encendida.

### Paso 11 · Entregar el acceso a A y B (10 min)

A cada uno, **por mensaje directo** (nunca en el grupo):

> Base compartida TechCare en Azure
> Servidor: `techcare-grupo5.database.windows.net` · Base: `TechCare` · Usuario: `dev_back` · Contraseña: (la del archivo)
> En SSMS: SQL Server Authentication + *Options → Connect to database:* TechCare. Encryption: Mandatory (sin "Trust server certificate").
> Puedes crear y cambiar SP, vistas, funciones y triggers; las tablas solo cambian con reconstrucción.
> El backend usa `techcare_app` (te paso la cadena aparte cuando la necesites).

En el grupo, solo: *"Base de Azure lista. Les mandé credenciales por privado. Manden su IP de https://ifconfig.me."*

### Paso 12 · Dejar la VM como plan B (opcional, 15 min)

En la VM con Windows Server 2022: instale SQL Server 2022 Developer y Tailscale, y deje el repo clonado. **No hace falta tenerla encendida todos los días.** Si Azure fallara, se reconstruye ahí con `./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_infra` (pasos completos en `GUIA_PASO_A_PASO.md`, sección C1).

### Checklist de fin del día

- [ ] Master corriendo en su laptop (`TechCare_Infra`) y en el CI (`db-build` en verde).
- [ ] `TechCare` en Azure con collation `Modern_Spanish_CI_AS`, esquema, datos, roles, usuarios y auditoría.
- [ ] Verificaciones 9.2 y 9.3 correctas.
- [ ] Firewall con las IP de A, B y C; los tres conectados.
- [ ] Presupuesto y alerta de cuota creados.
- [ ] Credenciales entregadas por privado; `infra/` fuera de git.
- [ ] 20:00 revisión del núcleo; 22:00 reconstrucción final y congelamiento.

---

## 5. Lo que hacen A y B hoy (40 min cada uno)

1. **SQL Server 2022 Developer** (Basic) en su laptop. En macOS: Docker Desktop con Rosetta y `mcr.microsoft.com/mssql/server:2022-latest`.
2. Herramientas: Git, PowerShell 7, sqlcmd, SSMS (o VS Code + extensión SQL Server en Mac).
3. Clonar el repo y crear su base personal:

   ```powershell
   cd database
   ./reconstruir.ps1 -Servidor localhost -Integrada -Db TechCare_Back     # B
   ./reconstruir.ps1 -Servidor localhost -Integrada -Db TechCare_Front    # A
   # macOS / Docker: ./reconstruir.sh -s localhost,1433 -u sa -d TechCare_Front
   ```

4. Mandar su IP a C (https://ifconfig.me) y conectarse a Azure con su usuario (mensaje del paso 11).
   - B, en desarrollo, puede apuntar el backend a su base local con autenticación de Windows: `Server=localhost;Database=TechCare_Back;Integrated Security=True;TrustServerCertificate=True` (en `dotnet user-secrets`). Para integrar, cambia a la cadena de `techcare_app` en Azure.
5. Probar desde la red de la universidad: `Test-NetConnection techcare-grupo5.database.windows.net -Port 1433`. Si falla allí, en la universidad trabajen contra su base local o con el hotspot del celular.

---

## 6. La rutina diaria (después de hoy)

1. Trabajar en la **base local**: escribir el objeto en su archivo (`CREATE OR ALTER`), ejecutarlo y probarlo.
2. **PR**: el check `db-build` lo construye todo desde cero; otro integrante lo revisa ejecutándolo en su base local.
3. **Merge** y despliegue **del archivo completo** en Azure con su usuario:

   ```powershell
   git switch main; git pull
   sqlcmd -S tcp:techcare-grupo5.database.windows.net,1433 -d TechCare -U dev_back -P *** -b -f 65001 -i database/41_sp_ordenes.sql
   ```

4. Avisar en el grupo: `Desplegado en TechCare: 41_sp_ordenes.sql`.
5. ¿Hay que cambiar una tabla? Protocolo 2.6 de la guía general: PR al núcleo aprobado por los tres y C reconstruye en la ventana de las 13:00 o las 21:00 con `tcadmin`. El trigger 51090 impide hacerlo por otro camino.

---

## 7. Publicar la web gratis

**Cuándo:** viernes 23 o sábado 24, cuando el flujo funcione de punta a punta. Hoy no.

### 7.1 Arquitectura

```text
Navegador ──► Cloudflare Pages (Nuxt estático)  https://techcare-grupo5.pages.dev
                 │  fetch https://…/api
                 ▼
             Azure App Service F1 (API .NET 8)  https://techcare-api-grupo5.azurewebsites.net
                 │  techcare_app
                 ▼
             Azure SQL Database  TechCare
```

| Pieza | Servicio gratis | Por qué |
|---|---|---|
| Frontend | **Cloudflare Pages** | Nuxt en modo SPA (`ssr: false`) es un sitio estático: Pages lo sirve gratis por CDN con HTTPS. El plan gratuito permite 500 builds al mes ([Cloudflare](https://developers.cloudflare.com/pages/platform/limits)) |
| API | **Azure App Service, plan Free (F1)** | Corre .NET 8 tal cual, en la misma región que la base. Gratis con límites: 60 minutos de CPU al día, 1 GB de memoria, 1 GB de almacenamiento y solo dominio `*.azurewebsites.net` ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits)). Para una demo, 60 minutos de **CPU** (no de reloj) alcanzan de sobra |
| Base | Azure SQL Database | La que ya tienen |

**¿Por qué no Cloudflare Workers para la API?** Workers ejecuta JavaScript/TypeScript y WebAssembly, no una API ASP.NET Core. Habría que reescribir el backend en otro lenguaje. Workers sirve para el frontend, no para .NET.

**Alternativa sin App Service:** Cloudflare Tunnel (`cloudflared tunnel --url http://localhost:5080`) publica la API que corre en una laptop con una URL temporal gratis. Sirve para mostrar algo rápido, pero depende de que esa laptop esté encendida: es justo lo que queríamos evitar.

### 7.2 Cambios en el backend (B, 15 min)

`Program.cs`, para aceptar varios orígenes (Pages y localhost) y, opcionalmente, servir la web desde la misma API (lo usa la presentación de la sección 8):

```csharp
// CORS: lista separada por comas en Cors:Front
var origenes = (cfg["Cors:Front"] ?? "")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(o => o.AddPolicy("front", p =>
    p.WithOrigins(origenes).AllowAnyHeader().AllowAnyMethod()));

// ...
var app = builder.Build();
app.UseMiddleware<SqlErrorMiddleware>();
app.UseDefaultFiles();      // sirve wwwroot/index.html si existe (modo presentación)
app.UseStaticFiles();
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors("front");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapFallbackToFile("index.html");   // rutas del SPA (/ordenes/15, /caja…) si hay wwwroot
app.Run();
```

### 7.3 Publicar la API en App Service F1 (C, 30 min)

```powershell
az login
az appservice plan create -g rg-techcare -n plan-techcare --sku F1 --is-linux --location <misma-region-que-la-base>
az webapp create -g rg-techcare -p plan-techcare -n techcare-api-grupo5 --runtime "DOTNETCORE:8.0"

# Configuración (equivale a user-secrets; ASP.NET la lee como Jwt:Key, Cors:Front, ConnectionStrings:TechCare)
az webapp config appsettings set -g rg-techcare -n techcare-api-grupo5 --settings `
  Jwt__Key="<cadena-aleatoria-64+>" Jwt__Issuer="techcare-api" Jwt__Audience="techcare-web" `
  Cors__Front="https://techcare-grupo5.pages.dev,http://localhost:3000"
az webapp config connection-string set -g rg-techcare -n techcare-api-grupo5 -t SQLAzure `
  --settings TechCare="<cadena de techcare_app de infra/credenciales_azure.txt>"

# Publicar
cd C:\src\techcare\backend\TechCare.Api
dotnet publish -c Release -o publish
Compress-Archive -Path publish\* -DestinationPath api.zip -Force
az webapp deploy -g rg-techcare -n techcare-api-grupo5 --src-path api.zip --type zip
```

Permitir que la API llegue a la base agregando **sus** IP de salida al firewall (más seguro que abrir "Allow Azure services"):

```powershell
$ips = (az webapp show -g rg-techcare -n techcare-api-grupo5 --query possibleOutboundIpAddresses -o tsv).Split(',')
$i = 0
foreach ($ip in $ips) { $i++; az sql server firewall-rule create -g rg-techcare -s techcare-grupo5 -n "api-$i" --start-ip-address $ip --end-ip-address $ip }
```

Prueba: abrir `https://techcare-api-grupo5.azurewebsites.net/swagger` y hacer login. La primera petición tarda unos segundos (el plan gratuito no tiene *Always On*).

### 7.4 Publicar el frontend en Cloudflare Pages (A o C, 20 min)

1. Cree una cuenta gratis en https://dash.cloudflare.com → *Workers & Pages* → **Create** → *Pages* → **Connect to Git** → elija el repo `techcare`.
2. Configuración del build:

   | Campo | Valor |
   |---|---|
   | Project name | `techcare-grupo5` (queda `https://techcare-grupo5.pages.dev`) |
   | Production branch | `main` |
   | Root directory | `frontend` |
   | Build command | `npx nuxi generate && rm -f .output/public/404.html` |
   | Build output directory | `.output/public` |
   | Variables de entorno | `NUXT_PUBLIC_API_BASE` = `https://techcare-api-grupo5.azurewebsites.net/api` · `NODE_VERSION` = `22` |

3. **Save and Deploy.** Cada merge a `main` publica una versión nueva sola.

Por qué el build borra `404.html`: Cloudflare Pages trata el sitio como aplicación de una sola página (todas las rutas sirven la app) cuando no hay un `404.html` en la raíz. Nuxt genera uno, así que se quita. Si al abrir `https://…pages.dev/ordenes/1` directamente ven un 404, revisen ese paso.

`NUXT_PUBLIC_API_BASE` se lee **al construir** el sitio: si cambia la URL de la API, hay que volver a desplegar.

### 7.5 Seguridad mínima de la versión pública

- Los usuarios de prueba (`Demo2026!`) quedan expuestos a cualquiera que tenga la URL. Para la demo está bien; **después del 30, detengan la app** (`az webapp stop -g rg-techcare -n techcare-api-grupo5`) o borren `rg-techcare`.
- La API pública solo puede hacer lo que `techcare_app` puede hacer: aunque alguien la ataque, no puede alterar stock, facturas ni pagos fuera de los SP. Es un buen argumento para la defensa.

---

## 8. La presentación con 3 computadoras y roles distintos

**Idea:** la laptop de demostración lo corre todo (SQL Server, API y web). Las otras dos computadoras solo abren el navegador apuntando a ella por la red local. Cada computadora inicia sesión con un rol distinto y se ve el flujo pasar de un rol a otro en tiempo real.

### 8.1 La red: el hotspot de un celular

Las redes Wi-Fi de universidad suelen aislar a los clientes entre sí (una laptop no ve a la otra). Para no depender de eso, **conecten las tres laptops al hotspot de un celular**: forma una red local propia, y funciona aunque el celular no tenga datos. Plan alternativo: un router de viaje.

### 8.2 Preparar la laptop de demostración (C, jueves 29, 40 min)

1. **Base local:** SQL Server Developer y `./reconstruir.ps1 -Servidor localhost -Integrada` (con la base `TechCare` también ejecuta `90_seguridad.sql` y crea el login `techcare_app`). La instalación *Basic* deja el servidor solo con autenticación de Windows; para que `techcare_app` pueda entrar, actívenla una vez: SSMS → clic derecho en el servidor → *Properties → Security* → **SQL Server and Windows Authentication mode** → reiniciar el servicio. Cambien también la contraseña de `techcare_app` en su copia de `90_seguridad.sql` antes de ejecutarlo.
2. **Web servida por la propia API** (un solo origen: sin CORS y sin IP fija en el build):

   ```powershell
   cd C:\src\techcare\frontend
   $env:NUXT_PUBLIC_API_BASE = "/api"          # ruta relativa: funciona desde cualquier computadora
   npx nuxi generate
   Remove-Item -Recurse -Force ..\backend\TechCare.Api\wwwroot -ErrorAction SilentlyContinue
   Copy-Item -Recurse .output\public ..\backend\TechCare.Api\wwwroot
   ```

3. **API escuchando en la red local** (con `Development` se usan los user-secrets de esa laptop, con la cadena a la base local y el usuario `techcare_app`):

   ```powershell
   cd C:\src\techcare\backend\TechCare.Api
   $env:ASPNETCORE_ENVIRONMENT = "Development"
   $env:ASPNETCORE_URLS = "http://0.0.0.0:5080"
   dotnet run --no-launch-profile
   ```

4. **Firewall de Windows** (PowerShell como administrador, una vez):

   ```powershell
   New-NetFirewallRule -DisplayName "TechCare demo 5080" -Direction Inbound -Protocol TCP -LocalPort 5080 -Action Allow -Profile Any
   ```

5. **La IP de la laptop** en la red del hotspot: `ipconfig` → *Adaptador de LAN inalámbrica Wi-Fi* → *Dirección IPv4* (por ejemplo `192.168.43.120`).
6. Desde las otras dos laptops: abrir `http://192.168.43.120:5080` en el navegador.

### 8.3 Reparto de roles y guion

| Computadora | Quién la maneja | Rol | Qué muestra |
|---|---|---|---|
| Laptop 1 (proyector) | C | Recepción → Administrador | Registra cliente, equipo y orden; al final, la entrega y la trazabilidad |
| Laptop 2 | B | Técnico (y Bodega en otra pestaña) | Diagnóstico, reparación, consumo de repuesto; en Bodega se ve bajar el stock |
| Laptop 3 | A | Caja | Factura, dos pagos parciales, intento de pago excesivo rechazado |

Guion sugerido (8 minutos): Recepción crea la orden → Técnico la diagnostica y, tras la autorización, repara y consume un repuesto → Bodega ve el movimiento y el stock → Caja factura y registra dos pagos parciales → Recepción entrega → trazabilidad completa en el proyector.

**Momento estrella:** con la misma factura abierta en la laptop 2 (con un usuario de Caja) y en la laptop 3, ambos intentan pagar el saldo completo al mismo tiempo. Uno pasa y el otro recibe "El pago excede el saldo pendiente": es `UPDLOCK` funcionando en vivo.

### 8.4 Planes de respaldo

- **Plan B, sin red local:** todo en la laptop 1, con **una pestaña por rol**. Como la sesión se guarda en `sessionStorage`, cada pestaña puede tener un usuario distinto (por ejemplo: pestaña normal = Recepción, otra pestaña = Técnico, ventana de incógnito = Caja).
- **Plan C, si hay buen internet:** las tres laptops abren `https://techcare-grupo5.pages.dev` (sección 7) contra la base de Azure. Recuerden que esa base y la local son copias distintas construidas con los mismos scripts.
- **Ensayo obligatorio el jueves 29** con el hotspot real, el celular real y las tres laptops, incluido el modo avión de la laptop 1 (con el hotspot del celular encendido).

---

## 9. Plan B de la base compartida: VM + Tailscale

Úsenlo solo si Azure for Students no se activa o si Azure falla varios días:

1. En la VM: SQL Server 2022 Developer + TCP/IP en 1433 + Tailscale (`vm-techcare`) + regla de firewall solo para `100.64.0.0/10`.
2. Logins y reconstrucción: `GUIA_PASO_A_PASO.md`, sección C1 (`./reconstruir.ps1 -Servidor vm-techcare,1433 -Usuario dev_infra`).
3. Las bases personales **siguen en la laptop de cada uno**: si la VM se apaga, nadie se bloquea; solo se pausa la integración.

---

## 10. Problemas que pueden aparecer hoy

| Síntoma | Causa | Solución |
|---|---|---|
| `reconstruir.ps1` no se puede ejecutar (scripts deshabilitados) | Política de ejecución de PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `Login failed for user 'dev_back'` (18456) | No indicó la base | SSMS → *Connect to database:* `TechCare`; sqlcmd → `-d TechCare` |
| `Cannot open server … requested by the login. Client with IP address … is not allowed` | Falta la regla de firewall de esa IP | Paso 6 con la IP que dice el mensaje |
| Error 40613 en la primera conexión | La base estaba en pausa | Reintentar a los 60 segundos |
| Error 51090 al desplegar | Intentó crear o borrar una tabla, índice o tipo con un usuario `dev_*` | Es lo esperado: protocolo de cambios al núcleo, lo aplica C con `tcadmin` |
| `There is already an object named …` | Ejecutó el master sobre una base con objetos | Usar `reconstruir.ps1` (limpia primero) |
| Tildes rotas (`Ã³`) | Falta `-f 65001` en sqlcmd | Agregarlo siempre |
| `Free offer applied!` no aparece | El servidor elegido no admite la oferta, o la suscripción es *Azure for Students Starter* | Elegir otra vez el servidor en el desplegable; confirmar la suscripción en *Subscriptions* |

---

### Fuentes

- [Azure SQL Database free offer — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer)
- [Azure for Students — Microsoft](https://azure.microsoft.com/en-us/free/students)
- [Límites de Azure App Service (plan Free) — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits)
- [Cuotas de App Service — Microsoft Learn](https://learn.microsoft.com/azure/app-service/web-sites-monitor)
- [Límites de Cloudflare Pages](https://developers.cloudflare.com/pages/platform/limits)
