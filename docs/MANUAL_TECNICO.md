# TechCare Solutions · Manual técnico

Sistema de servicio técnico, inventario y facturación. Este manual explica cómo está construido, cómo se instala y para qué sirve cada componente de la base de datos. Los pasos exactos para levantarlo están en el [README](../README.md); el modelo está en [`ER_TechCare.png`](ER_TechCare.png) y la normalización en [`normalizacion.md`](normalizacion.md).

## 1. Arquitectura

Tres capas. La web nunca habla con SQL Server: todo pasa por la API, y las reglas del negocio viven en la base de datos (procedimientos, restricciones y triggers), así que se cumplen aunque alguien escriba directo desde SSMS (R16).

```
 Navegador (Nuxt 4)  ──HTTPS/JSON──▶  API ASP.NET Core 8  ──Dapper, SQL parametrizado──▶  SQL Server
  pantallas por rol                    JWT, permisos,                                      tablas, constraints,
  validación de formulario             validación, 409/400                                 SP con transacciones,
                                       usuario techcare_app (rol_app)                      vistas, funciones, triggers
```

| Capa | Tecnología | Responsabilidad |
| --- | --- | --- |
| Web | Nuxt 4 (Vue 3, SPA), Nuxt UI 4, Pinia | Pantallas, menú y botones según los permisos del usuario, validación de formularios, mensajes de error de la API |
| API | .NET 8, Dapper 2.1, Microsoft.Data.SqlClient 7, JWT Bearer | Autenticación, autorización por permiso, validación de entrada, llamada a procedimientos y consultas parametrizadas, traducción de errores SQL a HTTP |
| Base de datos | SQL Server 2019+ / Azure SQL Database | Modelo relacional en 3FN, integridad, procesos transaccionales, reportes |

En producción la API sirve también la web compilada (una sola dirección): `https://techcare-api-grupo-bhl.azurewebsites.net`, con la base en Azure SQL (serverless).

## 2. Estructura del repositorio

```
backend/TechCare.Api/
  Auth/          PasswordService (hash), TokenService (JWT)
  Controllers/   una clase por área: Ordenes, Reparaciones, ReparacionRepuestos, Inventario, Compras,
                 Catalogos, ClientesEquipos, CajaConsultas, Pagos, AccionesFacturacion, Reportes, Dashboard, Auth
  Data/          repositorios Dapper (SQL parametrizado o EXEC de procedimientos) y SqlConnectionFactory
  Dtos/          cuerpos de las peticiones
  Middleware/    SqlErrorMiddleware (errores SQL -> HTTP) y UserExtensions (idUsuario del token)
  Program.cs     configuración: JWT, una política por permiso, CORS, archivos estáticos
frontend/app/
  pages/         login, inicio, ordenes (lista, trazabilidad), caja, inventario, kardex, compras, reportes
  components/    formularios de acciones (factura, pago, entrega, anulación, taller) y ReporteTabla
  stores/auth.ts sesión, roles y permisos;  composables/useApi.ts  llamadas con token y manejo de errores
  utils/         menú por permiso, definición de los 12 reportes, formatos (Q, fechas)
database/        scripts numerados (ver sección 4), pruebas/ (T03–T14, R14), build_master.ps1, reconstruir.ps1
deploy/          publicar.ps1 (web + API en Azure), crear-app-azure.ps1
docs/            ER, normalización, este manual, guías del equipo
```

## 3. Instalación y configuración

Resumen; los comandos exactos están en el README.

1. **Base de datos.** En orden: `TechCare_Master.sql` (estructura y lógica) → `TechCare_DatosPrueba.sql` (datos y escenarios) → `92_auditoria_ddl.sql` → `90_seguridad.sql` (cambiar antes la contraseña de `techcare_app`). `database/reconstruir.ps1` hace todo con un comando, en local o en Azure (`-Azure`). Los dos primeros se generan con `database/build_master.ps1`, que une los scripts numerados en orden.
2. **API.** Necesita dos valores que **no** están en el código: `ConnectionStrings:TechCare` (con el usuario `techcare_app`, nunca `sa`) y `Jwt:Key`. En desarrollo van en *user-secrets*; en Azure, en la configuración del App Service. `dotnet run` en `backend/TechCare.Api`.
3. **Web.** `npm install` y `npm run dev` en `frontend/` (con `NUXT_PUBLIC_API_BASE` apuntando a la API). Para una sola dirección: `deploy/publicar.ps1` compila la web y la copia a `wwwroot` de la API.

Usuarios de prueba: `administrador1`, `recepcion1`, `tecnico1`, `bodega1`, `caja1` (y sus `…2`), contraseña `Demo2026!`.

## 4. Base de datos

### 4.1 Orden de los scripts

| Archivo | Contenido |
| --- | --- |
| `01_base_datos` | Crea la base (en Azure se omite) |
| `02_tablas` | 31 tablas con PK, FK, UNIQUE, DEFAULT y CHECK con nombre |
| `03_indices` · `04_tipos` · `05_catalogos` | Índices no agrupados · tipo tabla `TipoDetalleCompra` · estados, transiciones, roles, permisos y métodos de pago |
| `10_funciones` | 5 funciones |
| `20`–`22_vistas_*` | 5 vistas |
| `30`–`31_triggers_*` | 3 triggers de tabla |
| `40`–`43_sp_*` | 18 procedimientos de proceso |
| `50`–`52_reportes_*` | 12 procedimientos de reporte |
| `80`–`85_datos_*` | Datos de prueba y escenarios (85 termina con verificaciones que deben decir OK) |
| `90_seguridad` · `91_seguridad_azure` | Login `techcare_app` y `rol_app` (mínimo privilegio) |
| `92_auditoria_ddl` | Tabla `AuditoriaDDL` (la 32.ª) y trigger de base de datos |

Todo lo programable usa `CREATE OR ALTER`, así que los scripts se pueden volver a ejecutar.

### 4.2 Tablas por área (32)

| Área | Tablas |
| --- | --- |
| Seguridad (5) | `Usuario`, `Rol`, `Permiso`, `UsuarioRol`, `RolPermiso` |
| Clientes y equipos (4) | `Cliente`, `Equipo`, `TipoEquipo`, `Marca` |
| Órdenes y taller (8) | `EstadoOrden`, `TransicionEstado`, `OrdenServicio`, `HistorialEstadoOrden`, `Diagnostico`, `Reparacion`, `ActividadReparacion`, `DetalleRepuesto` |
| Inventario y compras (9) | `CategoriaRepuesto`, `Repuesto`, `Bodega`, `Inventario`, `MovimientoInventario`, `Proveedor`, `Compra`, `DetalleCompra`, `AuditoriaPrecioRepuesto` |
| Facturación y entrega (5) | `Factura`, `DetalleFactura`, `MetodoPago`, `Pago`, `Entrega` |
| Auditoría de desarrollo (1) | `AuditoriaDDL` |

**Relaciones muchos a muchos (6):** Usuario–Rol (`UsuarioRol`), Rol–Permiso (`RolPermiso`), Bodega–Repuesto (`Inventario`, con existencia y stock mínimo), Compra–Repuesto (`DetalleCompra`, con costo histórico), Reparación–Repuesto (`DetalleRepuesto`, con precio y costo históricos) y Estado–Estado (`TransicionEstado`, qué cambio de estado está permitido).

**Llaves primarias compuestas (7):** `UsuarioRol (idUsuario, idRol)`, `RolPermiso (idRol, idPermiso)`, `Inventario (idBodega, idRepuesto)`, `DetalleCompra (idCompra, idRepuesto)`, `ActividadReparacion (idReparacion, numeroActividad)`, `DetalleFactura (idFactura, numeroLinea)`, `TransicionEstado (estadoOrigen, estadoDestino)`.

**Restricciones:** 50 FK, 20 UNIQUE (por ejemplo `Equipo.numeroSerie`, `Repuesto.codigo`, `Factura.idOrden` —R11—, `Factura (serie, numero)`, NIT de cliente único salvo `CF` con índice filtrado), 44 DEFAULT y 53 CHECK (cantidades positivas, existencia ≥ 0, estados válidos, contacto obligatorio del cliente, empresa con NIT distinto de CF, cuadre del movimiento: `existenciaResultante = existenciaAnterior ± cantidad`).

**Comportamiento de las FK.** 46 FK usan `NO ACTION` a propósito: la información transaccional no se borra (R14), así que borrar un padre con hijos debe fallar; los catálogos y clientes se desactivan con su columna `estado`. Solo las 4 FK de `UsuarioRol` y `RolPermiso` usan `ON DELETE CASCADE`: son asignaciones sin historia propia y, si se quita un rol, sus filas de asignación no tienen sentido. Ninguna FK usa `ON UPDATE CASCADE` porque las llaves son `IDENTITY` y no cambian.

### 4.3 Vistas (5)

| Vista | Uso |
| --- | --- |
| `vw_OrdenesActivas` | Órdenes no finalizadas con cliente, equipo y técnico (LEFT JOIN: el técnico se asigna después). Reporte 1 |
| `vw_InventarioActual` | Existencia por bodega y repuesto con `estadoStock` (OK, BAJO_MINIMO, SIN_STOCK) y valor. Reportes 6 y 7, pantalla de inventario, dashboard |
| `vw_MovimientosInventario` | Kárdex con documento origen: compra/proveedor o reparación/orden (LEFT JOIN según el origen). Reporte 9 y trazabilidad |
| `vw_FacturasSaldo` | Factura con total pagado, saldo y estado de pago calculados con funciones (R13). Caja, reporte 10, detalle de orden |
| `vw_DashboardResumen` | Conteos de la pantalla de inicio: órdenes por estado, facturas con saldo, saldo por cobrar, repuestos bajo mínimo |

### 4.4 Funciones (5)

| Función | Para qué |
| --- | --- |
| `fn_SaldoFactura(@idFactura)` | Saldo = total − pagos aplicados. El saldo **no se guarda** (R13) |
| `fn_TotalPagado(@idFactura)` | Suma de pagos en estado APLICADO (los anulados no cuentan) |
| `fn_TotalOrden(@idOrden)` | Mano de obra + repuestos a precio histórico; base de la factura |
| `fn_UsuarioTieneRol(@idUsuario, @rol)` | R03: el técnico que diagnostica o repara debe tener el rol (el administrador siempre puede) |
| `fn_HistorialEquipo(@numeroSerie)` | Función de tabla: todas las órdenes de un equipo con diagnóstico, reparación y factura. Reporte 3 (T11) |

### 4.5 Triggers (3 + 1)

| Trigger | Tipo | Qué protege |
| --- | --- | --- |
| `trg_OrdenServicio_Estado` | AFTER INSERT, UPDATE en `OrdenServicio` | Toda orden nace en RECIBIDO; cada cambio de estado debe existir en `TransicionEstado`; ENTREGADO exige entrega registrada, factura si hubo reparación y saldo cero; escribe `HistorialEstadoOrden` (R05) con el usuario de la aplicación. Errores 51001–51003 |
| `trg_Repuesto_AuditoriaPrecio` | AFTER UPDATE en `Repuesto` | Cada cambio de precio de venta o costo de referencia queda en `AuditoriaPrecioRepuesto` (quién, cuándo, antes y después). T14 |
| `trg_MovimientoInventario_Inmutable` | INSTEAD OF UPDATE, DELETE en `MovimientoInventario` | El kárdex no se edita ni se borra (R14); los errores se corrigen con un ajuste. Error 51010 |
| `trg_AuditoriaDDL` | DDL, sobre la base | Herramienta de desarrollo (92): registra quién cambió un procedimiento o vista en la base compartida e impide a los usuarios de desarrollo cambiar tablas. Error 51090 |

¿Cómo sabe un trigger qué usuario de la aplicación hizo el cambio? El procedimiento llama primero a `sp_EstablecerContexto`, que guarda `idUsuario` en `SESSION_CONTEXT`; el trigger lo lee. Si alguien actualiza desde SSMS, `idUsuario` queda vacío pero `usuarioBD` guarda el login de SQL.

### 4.6 Índices no agrupados (12)

| Índice | Consulta que mejora |
| --- | --- |
| `IX_OrdenServicio_Estado_Fecha` | Dashboard y reporte 1: órdenes por estado ordenadas por fecha |
| `IX_OrdenServicio_Equipo_Fecha` | Reporte 3 / historial de un equipo |
| `IX_Equipo_Cliente` | Reporte 2: equipos de un cliente |
| `IX_Pago_Factura` | `fn_SaldoFactura`, `fn_TotalPagado`, reporte 10 (pagos aplicados de una factura) |
| `IX_Movimiento_Bodega_Repuesto_Fecha` | Reporte 9: kárdex de un repuesto en una bodega |
| `IX_DetalleRepuesto_Reparacion` | Reportes 5 y 12, `fn_TotalOrden` |
| `IX_HistorialEstado_Orden_Fecha` | Trazabilidad e historial de una orden |
| `IX_Factura_FechaEmision` | Reporte 11: ingresos por período |
| `IX_Diagnostico_Tecnico_Fecha` | Reporte 4: trabajo por técnico en un rango de fechas |
| `IX_Compra_Proveedor_Fecha` | Reporte 8: compras por proveedor |
| `UX_Cliente_Nit` (único, filtrado) | NIT único salvo `CF` (consumidor final se repite) |
| `UX_Usuario_Email` (único, filtrado) | Email de usuario único cuando existe |

### 4.7 Procedimientos de proceso (18)

Los marcados con ✔ usan `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` en `TRY…CATCH` con `SET XACT_ABORT ON` (R15): si una parte falla, no queda nada aplicado.

| Procedimiento | Tx | Qué hace · reglas |
| --- | --- | --- |
| `sp_RegistrarOrdenServicio` | ✔ | Crea la orden en RECIBIDO con equipo, recepcionista, prioridad y fecha estimada (R01, R02) |
| `sp_RegistrarDiagnostico` | ✔ | Diagnóstico con técnico autorizado (R03); la orden pasa a ESPERANDO_AUTORIZACION |
| `sp_RegistrarAutorizacionCliente` | ✔ | Respuesta del cliente: si autoriza, queda lista para reparar; si rechaza, la orden pasa a LISTO para devolver el equipo |
| `sp_IniciarReparacion` | ✔ | Solo con diagnóstico autorizado (R04); orden a REPARACION |
| `sp_RegistrarActividad` | ✔ | Actividades numeradas de la reparación |
| `sp_FinalizarReparacion` | ✔ | Trabajo realizado y mano de obra; orden a LISTO |
| `sp_CambiarEstadoOrden` | ✔ | Cambio de estado genérico (por ejemplo CANCELADO), validado por el trigger |
| `sp_EstablecerContexto` | | Usuario y observación para los triggers (ver 4.5) |
| `sp_ListarOrdenes` · `sp_DetalleOrden` | | Lista con filtros y detalle de una orden (orden, diagnóstico, reparación, factura, historial) |
| `sp_UtilizarRepuesto` | ✔ | Valida técnico, reparación en proceso, que el repuesto exista en la bodega (R06) y stock con bloqueo `UPDLOCK, HOLDLOCK`; inserta el detalle con precio y costo del momento (R09), descuenta inventario y registra el movimiento de salida (R07, R10) |
| `sp_RegistrarCompra` | ✔ | Encabezado y detalle (parámetro tabla `TipoDetalleCompra`) con costo unitario histórico; queda PENDIENTE |
| `sp_RecibirCompra` | ✔ | Suma existencias y registra un movimiento de entrada por línea (R08); todo o nada |
| `sp_AjusteInventario` | ✔ | Única corrección manual de existencias, siempre con motivo y movimiento AJUSTE |
| `sp_FacturarOrden` | ✔ | Una factura por orden LISTO (R11); copia mano de obra y repuestos a `DetalleFactura` a precio histórico; subtotal, 12 % de impuesto y total |
| `sp_RegistrarPago` | ✔ | Valida método, referencia si el método la exige y que el monto no supere el saldo (R12) |
| `sp_AnularPago` | ✔ | No borra: marca ANULADO con motivo y el saldo vuelve a subir (R14) |
| `sp_EntregarOrden` | ✔ | Registra quién recibe y quién entrega; exige factura sin saldo si hubo reparación; orden a ENTREGADO |

### 4.8 Reportes (12)

Todos son procedimientos `sp_Reporte_NN_*`: sin `SELECT *`, sin `DISTINCT`, con alias legibles y filtros opcionales. La aplicación los muestra en `/reportes` (1–11) y en la trazabilidad de cada orden (12).

| # | Reporte | Filtros | Detalle técnico |
| --- | --- | --- | --- |
| 1 | Órdenes activas | estado, prioridad, técnico | `vw_OrdenesActivas` (LEFT JOIN al técnico) |
| 2 | Historial de un cliente | idCliente o NIT (obligatorio) | 8 tablas, LEFT JOIN: equipos sin órdenes y órdenes sin diagnóstico o factura no desaparecen |
| 3 | Historial de un equipo | número de serie | `fn_HistorialEquipo` (LEFT JOIN) |
| 4 | Diagnósticos y reparaciones por técnico | técnico, fechas | 6 tablas |
| 5 | Repuestos usados por orden | técnico, bodega, fechas | 8 tablas, precio y costo históricos |
| 6 | Inventario actual | bodega, categoría | `vw_InventarioActual` |
| 7 | Bajo mínimo | bodega | `vw_InventarioActual` (T13) |
| 8 | Compras por proveedor | proveedor, fechas, estado | 6 tablas, costo histórico |
| 9 | Movimientos de inventario | bodega, repuesto, fechas | `vw_MovimientosInventario` (LEFT JOIN por origen) |
| 10 | Facturas con saldo y sus pagos | cliente, fechas, incluir pagadas | Dos resultados: facturas y pagos |
| 11 | Ingresos por período | fechas | Mano de obra y repuestos por separado |
| 12 | Trazabilidad de una orden | orden | 16 tablas, 5 resultados, LEFT JOIN: una orden sin factura o sin pagos sigue apareciendo (T12) |

### 4.9 Errores y su traducción

Cada procedimiento lanza `THROW` con un código propio y un mensaje en español:

| Rango | Origen |
| --- | --- |
| 50001–50005 | Procedimientos comunes |
| 50101–50122 | Inventario y compras |
| 50201–50291 | Órdenes y taller (50280–50282: reportes 1–4) |
| 50301–50327 | Facturación (50325–50327: reportes 10–12) |
| 51001–51099 | Triggers (51001–51003 estados, 51010 kárdex, 51090 DDL) |

`SqlErrorMiddleware` de la API convierte los códigos 50000–51099 y las violaciones de PK, UNIQUE o FK (2627, 2601, 547) en **HTTP 409** con `{ "error": "mensaje" }`; la web muestra ese mensaje tal cual. La validación previa de la API responde **400**; sin sesión, **401**; sin permiso, **403**.

## 5. Seguridad

- **Contraseñas:** `PasswordHasher` de ASP.NET Core (PBKDF2 con sal aleatoria por usuario). En la base solo está el hash.
- **Sesión:** token JWT de 8 horas con el id del usuario, sus roles y sus permisos. El `idUsuario` que llega a los procedimientos sale **siempre del token**, nunca del cuerpo de la petición.
- **Roles y permisos relacionales:** 5 roles (Administrador, Recepción, Técnico, Bodega, Caja) y 14 permisos en `Permiso`/`RolPermiso`. La API tiene una política por permiso y la web oculta menús y botones según los mismos permisos.
- **Mínimo privilegio en la base:** la API se conecta como `techcare_app` (rol `rol_app`): puede ejecutar procedimientos y leer, y solo puede escribir en tablas de mantenimiento (clientes, equipos, catálogos, usuarios). Tiene `DENY` sobre las tablas transaccionales: el stock, el kárdex, las facturas y los pagos **solo cambian por procedimiento** (*ownership chaining*). Un `UPDATE Inventario SET existencia…` desde la aplicación falla.
- **SQL parametrizado:** Dapper con parámetros en todas las consultas; no se concatenan valores del usuario.
- **Secretos fuera del código:** cadena de conexión y llave JWT en *user-secrets* o en la configuración de Azure.

## 6. Decisiones que se pueden preguntar

- **Datos repetidos a propósito** (precio en `DetalleRepuesto`, costo en `DetalleCompra`, existencia en `Inventario`, `existenciaAnterior/Resultante` en el kárdex): están justificados en `normalizacion.md`; los precios históricos son exigencia de R09.
- **El saldo no se guarda:** se calcula con `fn_SaldoFactura` (R13), así nunca queda desactualizado.
- **El script de datos `85` apaga un momento `trg_MovimientoInventario_Inmutable`.** Solo para repartir en cuatro meses las fechas de los datos de prueba (los movimientos se generan "hoy" al correr los procedimientos). Lo hace dentro de una transacción, no toca cantidades ni existencias, ninguna restricción CHECK o FK se desactiva, y al final verifica que el kárdex siga cuadrado. En operación normal el trigger nunca se apaga.
- **`AuditoriaDDL` (tabla 32)** no es parte del negocio: protege la base compartida durante el desarrollo. Por eso se crea con un script aparte (`92`).
- **Fechas:** se guardan con `SYSDATETIME()` del servidor. En Docker y en Azure SQL el servidor está en UTC, así que lo registrado después de las 18:00 (hora de Guatemala) aparece con la fecha del día siguiente. Los datos de prueba no se ven afectados.
- **Concurrencia en inventario:** `sp_UtilizarRepuesto` lee la existencia con `UPDLOCK, HOLDLOCK`; si dos técnicos piden el último repuesto a la vez, el segundo espera y recibe "existencia insuficiente". La restricción `CHECK (existencia >= 0)` es la última red de seguridad (R10).

## 7. Pruebas

- `database/pruebas/`: scripts de T03 a T14 y R14 que imprimen `OK`/`FALLA`. Los que modifican datos (T04–T10, T13, T14, R14) lo hacen dentro de una transacción y terminan en `ROLLBACK`, así que no dejan cambios; T03, T11 y T12 son consultas de verificación.
- `85_datos_escenarios.sql` verifica al final los conteos mínimos, los escenarios obligatorios y la coherencia de fechas, y falla si algo no se cumple.
- CI en GitHub (`.github/workflows/db-build.yml`): cada PR que toca `database/` construye la base desde cero en SQL Server con el script maestro y los datos de prueba (incluidas las verificaciones de `85`); sin el check `sql` en verde no se puede mezclar a `master`.
- El plan con resultado esperado y obtenido de cada prueba está en `docs/PLAN_PRUEBAS.md`.
