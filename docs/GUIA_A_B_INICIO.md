# TechCare — Guía de inicio para A y B

> Para: A (Frontend) y B (Backend). Actualizada: martes 20 de octubre de 2026. Entrega: viernes 30.
> Tiempo total: unos 60 minutos. Sistema: **Windows 10/11**. Si usas Mac, avísale a C antes de empezar (allí se usa Docker).

**Qué vas a tener al terminar:**

1. SQL Server instalado en tu laptop con tu base personal (`TechCare_Back` para B, `TechCare_Front` para A), para probar sin miedo a romper nada.
2. El repo clonado y listo para trabajar con ramas y PR.
3. Acceso a la base compartida `TechCare` en Azure con tu propio usuario.

| Dato | Valor |
|---|---|
| Repo | https://github.com/DU1T/TechCareDB1 (privado) |
| Servidor Azure | `techcare-grupo-bhl.database.windows.net` (región West US) |
| Base compartida | `TechCare` |
| Tu usuario en Azure | A: `dev_front` · B: `dev_back` (la contraseña te la manda C por privado) |
| Tu base local | A: `TechCare_Front` · B: `TechCare_Back` |

---

## Paso 1 · Instalar herramientas (15 min)

Abre **Terminal** o **PowerShell** como usuario normal y ejecuta:

```powershell
winget install Git.Git
winget install Microsoft.PowerShell
```

Instala también **SSMS** (SQL Server Management Studio), que es la herramienta para ver y consultar las bases:

1. Busca **"Download SSMS"** en el sitio de Microsoft y descarga el instalador más reciente.
2. Ejecútalo con las opciones por defecto. Tarda unos 10 minutos; puedes seguir con el Paso 2 mientras tanto.

**Cierra la terminal.** Desde ahora, todo se hace en **PowerShell 7**: menú Inicio → escribe `pwsh` → abre *PowerShell 7*. Verifica:

```powershell
$PSVersionTable.PSVersion   # debe decir 7.x
git --version
```

> Importante: no uses la "Windows PowerShell" azul de siempre (versión 5.1). Los scripts del proyecto están hechos para PowerShell 7.

Configura tu nombre en git (una sola vez):

```powershell
git config --global user.name "Tu Nombre"
git config --global user.email "tu-correo@ejemplo.com"
```

---

## Paso 2 · Instalar SQL Server 2022 Developer (15 min)

1. Busca **"SQL Server 2022 Developer download"** en el sitio de Microsoft y descarga el instalador. Es gratis.
2. Ejecútalo y elige **Basic** (Básico). Acepta la licencia y la carpeta por defecto.
3. Al terminar, el instalador muestra el nombre de la instancia. Debe decir **MSSQLSERVER**. Si dice otra cosa (por ejemplo `SQLEXPRESS`), anótala: en los comandos usarás `localhost\SQLEXPRESS` en lugar de `localhost`.
4. Cierra el instalador. **No hace falta** abrir *SQL Server Configuration Manager* ni cambiar nada más.

Verifica que el servicio está encendido: menú Inicio → **Servicios** → busca **SQL Server (MSSQLSERVER)** → estado *En ejecución*.

Prueba la conexión desde PowerShell 7:

```powershell
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE" -S localhost -E -C -Q "SELECT @@VERSION"
```

Debe mostrar *Microsoft SQL Server 2022 … Developer Edition*.

- Si dice *Cannot generate SSPI context*, cambia `localhost` por `.` (un punto) en este comando y en todos los siguientes.
- Si la ruta del `SQLCMD.EXE` no existe, prueba solo `sqlcmd -S localhost -E -C -Q "SELECT @@VERSION"`.

---

## Paso 3 · Clonar el repo (5 min)

1. Revisa tu correo: C te invitó a **DU1T/TechCareDB1**. Acepta la invitación (o entra al repo en GitHub y acéptala desde el aviso).
2. Clona el repo en una carpeta sin espacios ni tildes, por ejemplo `C:\src`:

```powershell
mkdir C:\src -Force
cd C:\src
git clone https://github.com/DU1T/TechCareDB1.git techcare
cd techcare
```

La primera vez, git abre el navegador para iniciar sesión en GitHub: acepta.

3. Permite que corran los scripts del proyecto (una sola vez):

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File
```

---

## Paso 4 · Crear tu base personal (5 min)

```powershell
cd C:\src\techcare\database
./reconstruir.ps1 -Servidor localhost -Integrada -Base TechCare_Back     # B
./reconstruir.ps1 -Servidor localhost -Integrada -Base TechCare_Front    # A
```

Ejecuta **solo la línea que te corresponde**. Salida esperada:

```text
sqlcmd: C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE
OK -> ...\build\TechCare_Back_Master.sql (18 archivos)
OK -> ...\build\TechCare_Back_DatosPrueba.sql (6 archivos)
>> TechCare_Back_Master.sql
...
>> TechCare_Back_DatosPrueba.sql
>> 92_auditoria_ddl.sql
Listo: TechCare_Back reconstruida en localhost
```

El script borra y vuelve a crear tu base desde cero. Puedes ejecutarlo todas las veces que quieras: **es tu botón de reinicio** si rompes algo.

### Verificar

Abre **SSMS**. Aparece la ventana *Connect to Server*:

| Campo | Valor |
|---|---|
| Server type | Database Engine |
| Server name | `localhost` (o `.` si tuviste el error SSPI; o `localhost\SQLEXPRESS` si tu instancia tiene nombre) |
| Authentication | **Windows Authentication** |
| Encryption | Mandatory |
| **Trust server certificate** | **Marcado** (tu SQL local usa un certificado propio) |

Clic en **Connect**. En el panel izquierdo (*Object Explorer*) despliega **Databases**: debe aparecer `TechCare_Back` (o `TechCare_Front`).

Clic derecho en tu base → **New Query**. Revisa que arriba, en el selector de bases, diga tu base y no `master`. Pega y ejecuta con **F5**:

```sql
SELECT type_desc, COUNT(*) AS cantidad
FROM sys.objects
WHERE is_ms_shipped = 0 AND type IN ('U', 'V', 'P', 'FN', 'IF', 'TR')
GROUP BY type_desc;
```

Esperado hoy: **32** tablas, **1** vista, **6** procedimientos, **4** funciones escalares, **1** trigger. Si coincide, tu base local está lista.

---

## Paso 5 · Conectarte a Azure (10 min)

### 5.1 Mandar tu IP a C

Azure solo deja entrar a las IP registradas. Abre https://ifconfig.me y mándale ese número a C. Espera su confirmación antes de seguir.

Tu IP cambia si te conectas desde otro lugar (universidad, celular, casa de alguien). Cada lugar nuevo = mandar la IP nueva a C.

### 5.2 Conectarte

C te manda por **mensaje privado** tu contraseña. Nunca la pegues en el grupo, en git ni en el código.

En SSMS: **File → Connect Object Explorer** (o el ícono de enchufe en *Object Explorer*). En la ventana *Connect to Server*:

| Campo | Valor |
|---|---|
| Server type | Database Engine |
| Server name | `techcare-grupo-bhl.database.windows.net` |
| Authentication | **SQL Server Authentication** |
| Login | `dev_back` (B) o `dev_front` (A) |
| Password | La que te mandó C · marca *Remember password* |
| Encryption | **Mandatory** |
| Trust server certificate | **Sin marcar** (Azure tiene certificado válido) |

Antes de conectar, clic en **Options >>** (abajo a la derecha) → pestaña **Connection Properties** → en **Connect to database** escribe `TechCare` (no lo elijas de la lista: escríbelo). Luego **Connect**.

La base `TechCare` es **obligatoria**: tu usuario solo existe dentro de esa base. Sin ella, el error es *Login failed* (18456).

En *Object Explorer* ahora tienes dos servidores: `localhost` (tu base local) y `techcare-grupo-bhl…` (Azure). Para trabajar en uno, haz **clic derecho en su base → New Query**. La barra de estado de abajo de cada pestaña muestra el servidor y el usuario: **revísala siempre antes de ejecutar**.

La primera conexión del día puede tardar hasta un minuto o fallar con el error **40613**: la base estaba en pausa para ahorrar crédito. Reintenta a los 60 segundos.

### 5.3 Prueba rápida

```sql
SELECT DB_NAME() AS base, SUSER_NAME() AS usuario, COUNT(*) AS tablas
FROM sys.tables;
```

Debe mostrar `TechCare`, tu usuario y `32`.

### 5.4 Desde la universidad

Antes de ir, prueba desde la red de la universidad:

```powershell
Test-NetConnection techcare-grupo-bhl.database.windows.net -Port 1433
```

Si `TcpTestSucceeded` dice `False`, la red de la universidad bloquea el puerto. Allí trabaja con tu base local o con el hotspot del celular (y manda esa IP a C).

---

## Paso 6 · Qué puedes y qué no puedes hacer en Azure

| Puedes | No puedes |
|---|---|
| Leer y escribir datos de prueba | Crear, cambiar o borrar **tablas**, índices o tipos |
| Ejecutar procedimientos y funciones | Hacer `DROP` de cualquier objeto |
| **Crear y cambiar** procedimientos, vistas, funciones y triggers con `CREATE OR ALTER` | Dar permisos a otros |
| Ver planes de ejecución y bloqueos | Usar el usuario `tcadmin` (solo C) |

Si intentas algo prohibido, la base responde con el error **51090**. No es un problema: es la protección funcionando. Si de verdad hace falta cambiar una tabla, sigue el protocolo del Paso 8.5.

Cada cambio de estructura queda registrado en `dbo.AuditoriaDDL` con tu usuario, el objeto y la hora.

---

## Paso 7 · Tus archivos

Cada uno es dueño de sus archivos en `database/`. Solo editas los tuyos; los del núcleo no se tocan sin acuerdo de los tres.

| Dueño | Archivos |
|---|---|
| **B · Backend** | `20_vistas_ordenes.sql` · `41_sp_ordenes.sql` · `50_reportes_ordenes.sql` · `80_datos_usuarios.sql` · `83_datos_ordenes.sql` |
| **A · Frontend** | `22_vistas_facturacion.sql` · `43_sp_facturacion.sql` · `52_reportes_facturacion.sql` · `84_datos_facturacion.sql` |
| C · Infra | `21`, `31`, `42`, `51`, `81`, `82`, `85`, `90`–`92`, scripts |
| **Núcleo** (congelado) | `01`–`05`, `10`, `30`, `40`: solo por PR aprobado por los tres |

Reglas de escritura:

- Vistas, funciones, SP y triggers **siempre** con `CREATE OR ALTER` (se pueden re-ejecutar).
- Errores con `THROW` en tu rango: **502xx** órdenes (B) · **503xx** facturación (A).
- Nada se crea "a mano" en SSMS sin que esté en tu archivo y en git.
- No edites nada dentro de `database/build/`: se regenera solo.

---

## Paso 8 · La rutina diaria

```text
rama nueva → editar tu .sql → probar en tu base LOCAL → PR → db-build verde + 1 aprobación → merge → desplegar en AZURE → avisar
```

### 8.1 Empezar una tarea

```powershell
cd C:\src\techcare
git switch main
git pull
git switch -c b/sp-diagnostico        # B: b/<tarea> · A: a/<tarea>
```

### 8.2 Escribir y probar en tu base local

Edita tu archivo (por ejemplo `database/41_sp_ordenes.sql`) y ejecútalo **completo** contra tu base local:

```powershell
cd C:\src\techcare\database
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE" `
  -S localhost -E -C -b -I -f 65001 -d TechCare_Back -i 41_sp_ordenes.sql
```

Qué significa cada opción (no las quites):

| Opción | Para qué |
|---|---|
| `-b` | Se detiene en el primer error |
| `-I` | Activa `QUOTED_IDENTIFIER`. **Sin esto, tus SP fallan después** con los índices filtrados (error 1934) |
| `-f 65001` | Lee el archivo en UTF-8: sin esto, las tildes salen como `Ã³` |
| `-C` | Confía en el certificado de tu SQL local (solo local, nunca en Azure) |
| `-d` | La base destino |

**También puedes ejecutarlo desde SSMS:** *File → Open → File…* → elige tu `.sql` → en el selector de bases de arriba elige tu base local → **F5**. SSMS ya trae `QUOTED_IDENTIFIER` activado y entiende los `GO`. Para Azure, en cambio, despliega siempre con sqlcmd desde `main` (Paso 8.4), así queda exactamente el archivo del repo.

Para probar, abre una pestaña nueva en tu base local (clic derecho → *New Query*) y usa una transacción que se deshace sola:

```sql
BEGIN TRAN;
    EXEC dbo.sp_TuProcedimiento @param = 1;
    SELECT * FROM dbo.TablaAfectada WHERE ...;   -- revisa el efecto
ROLLBACK;                                        -- nada queda guardado
```

¿Rompiste tu base local? Vuelve a correr el Paso 4. Tarda un minuto.

### 8.3 Subir y abrir el PR

```powershell
cd C:\src\techcare
git add database/41_sp_ordenes.sql
git commit -m "SP de diagnóstico de órdenes"
git push -u origin b/sp-diagnostico
```

En GitHub aparece el botón **Compare & pull request**: ábrelo, llena la plantilla y asigna como revisor a otro integrante.

- El check **`db-build`** construye toda la base desde cero en un SQL Server limpio. Debe salir en **verde**.
- El revisor descarga tu rama, la ejecuta en **su** base local y aprueba.
- Si `db-build` sale en rojo: abre *Details*, lee el error, corrige, y haz `git commit` + `git push` en la misma rama. El check se vuelve a correr solo.

### 8.4 Merge y despliegue en Azure

Después del merge, despliega **el archivo completo desde `main`**:

```powershell
cd C:\src\techcare
git switch main
git pull
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE" `
  -S "tcp:techcare-grupo-bhl.database.windows.net,1433" -d TechCare -U dev_back `
  -b -I -f 65001 -i database/41_sp_ordenes.sql
```

Te pide la contraseña. En Azure **no** se usa `-C`. El servidor va entre comillas porque lleva coma.

Luego avisa en el grupo: `Desplegado en TechCare: 41_sp_ordenes.sql`.

### 8.5 ¿Necesitas cambiar una tabla?

1. Abre un PR que cambie `02_tablas.sql` (o el archivo del núcleo que corresponda), explicando por qué.
2. Lo aprueban **los tres**.
3. C reconstruye Azure en la ventana de las **13:00** o las **21:00**, avisando antes. Las tablas solo cambian así.

---

## Paso 9 · Solo para B: el backend

En desarrollo, apunta la API a **tu base local** con autenticación de Windows. En la carpeta del proyecto de la API:

```powershell
dotnet user-secrets set "ConnectionStrings:TechCare" "Server=localhost;Database=TechCare_Back;Integrated Security=True;TrustServerCertificate=True"
```

Para integrar con A contra Azure, C te pasa **por privado** la cadena del usuario `techcare_app` y la cambias con el mismo comando. El backend **nunca** usa `dev_back` ni `tcadmin`: `techcare_app` solo puede ejecutar SP y leer, y no puede tocar inventario, facturas ni pagos directamente. Eso es parte de la defensa.

Las cadenas de conexión van **solo** en `user-secrets`, nunca en `appsettings.json` ni en git.

---

## Paso 10 · Reglas del equipo

- **Cierra la conexión a Azure al terminar**: en SSMS, clic derecho en el servidor de Azure → **Disconnect**, y cierra las pestañas de consulta que apunten a Azure (cada pestaña es una conexión abierta). Detén también el backend. Una conexión abierta mantiene la base encendida y gasta crédito.
- Contraseñas solo por mensaje privado. Si crees que se filtró una, avísale a C para cambiarla.
- Nada de datos a mano en Azure: los datos de prueba salen de los scripts `80`–`85`.
- Antes de ejecutar algo, revisa **a qué conexión** estás apuntando (local o Azure): en SSMS aparece en la barra amarilla/gris de abajo de cada pestaña y en el selector de base de arriba.

---

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `reconstruir.ps1 no se reconoce` | No estás en la carpeta `database` | `cd C:\src\techcare\database` |
| "no está firmado digitalmente" o scripts deshabilitados | Política de ejecución | Paso 3.3 (`Set-ExecutionPolicy` + `Unblock-File`) |
| Mensajes como "En línea: 1 Carácter: 1" | Estás en Windows PowerShell 5.1 | Abre **PowerShell 7** (`pwsh`) |
| `Cannot generate SSPI context` | Autenticación de Windows por TCP | Usa `.` en lugar de `localhost` |
| No conecta a `localhost` | Servicio apagado o instancia con nombre | *Servicios* → SQL Server en ejecución; usa `localhost\SQLEXPRESS` si aplica |
| `No se puede convertir el valor al tipo System.String` | Servidor con coma sin comillas | `-Servidor "tcp:...,1433"` |
| `Sqlcmd: 'f': Unknown Option` | Estás usando el sqlcmd nuevo (go-sqlcmd) | Usa la ruta completa del `SQLCMD.EXE` clásico, como en esta guía |
| Error **1934** `QUOTED_IDENTIFIER` | Faltó `-I` | Agrega `-I` y vuelve a ejecutar el archivo |
| Tildes rotas (`Ã³`) | Faltó `-f 65001` | Agrégalo |
| `Login failed for user 'dev_back'` (18456) | No indicaste la base | SSMS: *Connect to database* `TechCare` · sqlcmd: `-d TechCare` |
| `Client with IP address … is not allowed` | Tu IP no está registrada | Manda a C la IP que dice el mensaje |
| Error **40613** | La base de Azure estaba en pausa | Reintenta a los 60 segundos |
| Error **51090** | Intentaste crear o borrar tabla, índice o tipo | Es lo esperado: protocolo 8.5 |
| `There is already an object named …` | Ejecutaste un `CREATE` sin `OR ALTER`, o el master sobre una base con objetos | Usa `CREATE OR ALTER`; para tu base local, Paso 4 |
| `db-build` en rojo en el PR | Tu archivo falla en una base limpia | *Details* → leer el error → corregir → push a la misma rama |

Si algo no está aquí: copia el error **completo** y mándalo al grupo.
