# TechCare Solutions · Plan y evidencia de pruebas

Entregable 08: casos funcionales (T01–T14 del enunciado) y de integridad (R14, R16), con resultado esperado, resultado obtenido y la salida real como evidencia.

## 1. Cómo se ejecutaron

| | |
| --- | --- |
| Fecha | viernes 30 de octubre de 2026 |
| Versión | Scripts SQL y T01–T03: `master` `04b78c5` (incluye el trigger `trg_Pago_NoExcedeTotal`, PR #38); regresión de los 10 scripts SQL el mismo día sobre `master` `4473f17` (119 OK, 0 FALLA). Prueba de punta a punta y reportes §5.1: `master` `0a5b49b` + commit `9b8aac8` (correcciones del API) |
| Base | `TechCare_Pruebas` construida desde cero (script maestro + datos de prueba + `92`, los mismos pasos de `reconstruir.ps1`) en SQL Server 2022 (Docker), más `90_seguridad.sql` (usuario `techcare_app` en `rol_app`) |
| API | ASP.NET Core 8 conectada como `techcare_app` (mínimo privilegio), igual que en producción |
| Scripts | `database/pruebas/*.sql`, ejecutados con `sqlcmd` como `sa`; T01–T03 por la API con usuarios de cada rol |
| Evidencia | `docs/evidencia_pruebas/<prueba>.txt`: salida completa, sin editar |

**Resultado global: 119 verificaciones SQL en OK, 0 FALLA** (20 de integridad directa, 13 de R14, 15 de T04–T05, 14 de T06, 10 de T07, 18 de T08–T10, 4 de T12, 11 de T13, 13 de T14, T01–T03 y T11), **más 109 verificaciones de punta a punta por la API en OK, 0 FALLA** (sección 4) y el cumplimiento de la sección 5.1 del enunciado sobre los 12 reportes (sección 4.2).

Para repetirlas en una base personal: construir la base (`database/reconstruir.ps1`), abrir cada script de `database/pruebas/` y ejecutarlo; cada uno imprime `OK` o `FALLA` por verificación. T04–T07, T13, T14, R14 y R16 terminan en `ROLLBACK` (no dejan cambios); **T08–T10 confirma cambios** y se niega a correr en la base compartida `TechCare`.

## 2. Pruebas funcionales del enunciado (T01–T14)

| Prueba | Escenario | Cómo | Resultado esperado | Resultado obtenido | Evidencia |
| --- | --- | --- | --- | --- | --- |
| **T01** | Registrar un cliente y dos equipos | API `POST /clientes` y 2 × `POST /equipos` con `recepcion1` | Cliente creado con sus 2 equipos | ✅ Cliente 33 (empresa, NIT 7788990-1) con equipos 71 y 72; `GET /clientes/33/equipos` los devuelve | `T01_T03_api.txt` |
| **T02** | Crear una orden y comprobar su estado inicial | API `POST /ordenes` con `recepcion1` | Orden en RECIBIDO con cliente, equipo, recepcionista y primera fila de historial | ✅ OS-000063 en RECIBIDO, prioridad ALTA, recepción `recepcion1`; historial `NULL → RECIBIDO "Orden registrada"` | `T01_T03_api.txt` |
| **T03** | Registrar diagnóstico con técnico responsable y cambiar el estado | API `POST /ordenes/63/diagnostico` con `tecnico1` | Diagnóstico con técnico; orden a ESPERANDO_AUTORIZACION; historial con el usuario; un rol sin permiso es rechazado | ✅ Diagnóstico 49 de `tecnico1` (Q 250); historial `RECIBIDO → DIAGNOSTICO → ESPERANDO_AUTORIZACION` por `tecnico1`; `recepcion1` → 403 | `T01_T03_api.txt` |
| **T04** | Usar un repuesto sin stock suficiente | `T04_T05_consumo_repuesto.sql` | Rechazo sin cambios parciales | ✅ Sin stock → 50106; cantidad 0 → 50101; usuario no técnico → 50102; reparación finalizada → 50103; repuesto fuera de la bodega → 50104. Inventario, repuestos usados y kárdex iguales que antes; ninguna transacción abierta | `T04_T05_consumo_repuesto.txt` |
| **T05** | Usar un repuesto con stock | mismo script | Detalle de reparación + salida de inventario + movimiento | ✅ Detalle con precio 350.00 y costo 210.00 del momento; existencia 4 → 3; movimiento SALIDA/REPARACION enlazado al detalle y encadenado al anterior; consumir el resto deja SIN_STOCK; existencia = suma del kárdex | `T04_T05_consumo_repuesto.txt` |
| **T06** | Registrar una compra con varios repuestos y recibirla | `T06_compra_recepcion.sql` | Inventario sube y se generan movimientos de entrada | ✅ Compra en PENDIENTE con costo propio por línea (no el del catálogo); registrar no mueve inventario; al recibir, existencias suben en lo comprado, un repuesto nuevo obtiene su fila en la bodega y hay 1 ENTRADA/COMPRA por línea (3 de 3). Errores (rol, sin líneas, documento repetido, recibir dos veces) sin dejar nada | `T06_compra_recepcion.txt` |
| **T07** | Provocar un error en una operación transaccional | `T07_rollback.sql` | Todo se revierte con ROLLBACK | ✅ A: movimiento que no cuadra → 547 y con `XACT_ABORT ON` la transacción queda condenada; existencia sin cambio. B: sin `XACT_ABORT` el descuento quedaría a medias (por eso los SP lo usan). C: ajuste + consumo fallido (50106) → también se deshace el ajuste | `T07_rollback.txt` |
| **T08** | Generar una factura desde una orden terminada | `T08_T10_facturacion.sql` | Total = mano de obra + repuestos + 12 % | ✅ total = subtotal + 12 %; segunda factura → 50313; orden no LISTO → 50312; usuario sin rol de caja → 50301 | `T08_T10_facturacion.txt` |
| **T09** | Dos pagos parciales y saldo restante | mismo script | El saldo baja con cada pago | ✅ Saldo 343.47 → 171.74 → 0 (el tercer pago completa); factura ya pagada → 50307; entrega con saldo → 50324 | `T08_T10_facturacion.txt` |
| **T10** | Pago que excede el saldo | mismo script | Rechazado | ✅ Pago mayor al saldo → 50308; tarjeta sin referencia → 50304; ningún pago insertado. Además: anulación sin motivo → 50315, pago anulado (no borrado) y saldo de vuelta, anular dos veces → 50317, anular tras entregar → 50318, `UPDATE` directo a ENTREGADO → 51003 | `T08_T10_facturacion.txt` |
| **T11** | Historial completo de un equipo con varias órdenes | `T11_historial_equipo.sql` (reporte 3, SN-00001) | Las 3 órdenes, incluidas las que no tienen diagnóstico ni factura | ✅ 3 órdenes (2 CANCELADO sin diagnóstico, 1 ENTREGADO con reparación y factura); 2 órdenes sin factura se conservan | `T11_historial_equipo.txt` |
| **T12** | Trazabilidad completa de una orden | `T12_reportes_facturacion.sql` (reportes 10, 11 y 12) | Datos de cliente a pagos; totales consistentes; errores controlados | ✅ Reporte 10 coincide con `fn_SaldoFactura`; total del reporte 11 = facturas emitidas; la salida incluye la trazabilidad completa de una orden (encabezado, repuestos, movimientos, pagos e historial); orden inexistente → 50327; fechas invertidas → 50325 | `T12_reportes_facturacion.txt` |
| **T13** | Repuestos bajo el stock mínimo en distintas bodegas | `T13_estado_stock.sql` | Estado correcto por bodega y en el dashboard | ✅ `estadoStock` correcto en las 90 filas; BAJO_MINIMO en las 3 bodegas; dashboard = vista (30 → 31 tras el ajuste); existencia = mínimo → BAJO_MINIMO, 0 → SIN_STOCK, mínimo + 1 → OK; cada ajuste deja su movimiento | `T13_estado_stock.txt` |
| **T14** | Un cambio de precio no modifica los históricos | `T14_precio_historico.sql` | Facturas, detalles y compras anteriores iguales; el cambio queda auditado | ✅ Precio 450.00 → 495.00; facturas, líneas, repuestos usados, costos de compra y kárdex sin diferencias; auditoría con antes/después y el usuario de la aplicación; un `UPDATE` sin cambio de precio no audita | `T14_precio_historico.txt` |

## 3. Pruebas de integridad

### R14 · Nada transaccional se borra (`R14_kardex_inmutable.sql`)

| Caso | Esperado | Obtenido |
| --- | --- | --- |
| `DELETE` de un movimiento, de todo el kárdex, `UPDATE` de cantidad o de la observación | Rechazo | ✅ Los 4 → 51010; el kárdex sigue con 145 movimientos y el movimiento 1 sin cambios |
| Corregir con un ajuste | Movimiento nuevo, encadenado | ✅ AJUSTE SALIDA de 1 con motivo, 4 → 3; existencia = suma del kárdex |
| `DELETE` de una factura con pagos o de una compra recibida | Rechazo por FK | ✅ Ambos → 547 |

Evidencia: `R14_kardex_inmutable.txt` (13 OK).

### R16 · Restricciones activas aunque se escriba directo en SQL (`R16_integridad_directa.sql`)

Cada caso se ejecuta directo, sin procedimientos, dentro de una transacción que termina en ROLLBACK.

| Caso | Operación directa | Esperado | Obtenido |
| --- | --- | --- | --- |
| I01 | `UPDATE Inventario SET existencia = -1` | Rechazo | ✅ 547 `CK_Inventario_Existencia` |
| I02 | Movimiento cuya existencia resultante no cuadra | Rechazo | ✅ 547 `CK_Movimiento_Cuadre` |
| I03–I04 | Borrar o modificar un movimiento del kárdex | Rechazo | ✅ 51010 trigger |
| I05 | Segunda factura para la misma orden (R11) | Rechazo | ✅ 2627 `UQ_Factura_Orden` |
| I06 | Saltar de RECIBIDO a ENTREGADO | Rechazo | ✅ 51002 transición no permitida |
| I07 | Marcar ENTREGADO una orden con saldo | Rechazo | ✅ 51003 |
| I08 | `INSERT` de un pago de Q 99,999 sobre una factura con saldo (R12) | Rechazo | ✅ 51011 `trg_Pago_NoExcedeTotal` |
| I09 | Pago con monto 0 | Rechazo | ✅ 547 `CK_Pago_Monto` |
| I10 | Empresa con NIT CF | Rechazo | ✅ 547 `CK_Cliente_NitEmpresa` |
| I11 | Cliente sin teléfono ni correo | Rechazo | ✅ 547 `CK_Cliente_Contacto` |
| I12 | Número de serie repetido | Rechazo | ✅ 2627 `UQ_Equipo_NumeroSerie` |
| I13 | Equipo de un cliente inexistente | Rechazo | ✅ 547 `FK_Equipo_Cliente` |
| I14 | Borrar un cliente con equipos | Rechazo (FK `NO ACTION`) | ✅ 547 `FK_Equipo_Cliente` |
| I15 | Detalle de compra con cantidad 0 | Rechazo | ✅ 547 `CK_DetalleCompra_Cantidad` |
| I16 | `techcare_app` cambia el stock directo | Rechazo por permisos | ✅ 230: UPDATE denegado en `Inventario.existencia` |
| I17 | `techcare_app` inserta un pago directo | Rechazo por permisos | ✅ 229: INSERT denegado en `Pago` |
| I18 | Subir directo el monto de un pago por encima del total | Rechazo | ✅ 51011 |
| I19 | Pago directo de Q 1 dentro del saldo | **Aceptado** | ✅ Aceptado (saldo baja en Q 1) |
| I20 | Pago directo que completa el total exacto | **Aceptado** | ✅ Aceptado (saldo 0.00) |

Evidencia: `R16_integridad_directa.txt` (20 OK, 0 FALLA).

## 4. Prueba de punta a punta por la API (`backend/pruebas/prueba_api_e2e.py`)

Los scripts SQL prueban la base; esta prueba usa el sistema como lo haría la aplicación: entra con los 5 roles, llama a la API real (conectada como `rol_app`, nunca como `sa`) y comprueba el resultado **y** que lo rechazado no deje cambios a medias. Evidencia completa: `docs/evidencia_pruebas/E2E_api.txt`. **109 OK, 0 FALLA.**

| Bloque | Qué se comprueba | Verificaciones |
| --- | --- | --- |
| Seguridad y roles | Los 5 roles inician sesión; clave incorrecta, sin token y token falso dan 401; bodega no crea clientes, caja no crea órdenes, recepción no ve usuarios y técnico no factura (403) | 8 |
| Clientes y equipos (T01) | Alta de empresa con ñ y tildes, NIT repetido y NIT `CF` de empresa, cliente sin contacto, dos equipos, serie repetida, búsqueda y edición. Los repetidos devuelven 409 con un mensaje que nombra el dato (NIT, serie) | 10 |
| Orden (T02) | Orden en `RECIBIDO` con la prioridad pedida; prioridad inválida y equipo inexistente rechazados | 4 |
| Diagnóstico y reparación (T03) | Recepción no diagnostica; no se repara sin diagnóstico (R06); diagnóstico lleva a `ESPERANDO_AUTORIZACION`; costo negativo rechazado; autorización; inicio de reparación | 6 |
| Repuestos (T04–T05) | Sin stock, cantidad mayor a la existencia, cantidad 0 y repuesto inexistente se rechazan **y el inventario queda igual**; con stock baja exactamente lo usado y el kárdex registra la `SALIDA` con su existencia anterior y resultante; horas fuera de rango rechazadas; reparación finalizada no admite más repuestos; la orden queda en `LISTO` | 15 |
| Factura, pagos y entrega (T08–T10) | Total = (mano de obra + repuestos al precio del momento) + 12 % de IVA; segunda factura (409); entrega con saldo rechazada; dos pagos parciales; saldo esperado; pago que excede el saldo y pago de 0 rechazados sin cambiar el saldo; el pago final deja el saldo en 0; factura pagada no admite más pagos; entrega y segunda entrega rechazada | 17 |
| Rechazo del cliente | La orden pasa a `LISTO` sin reparación | 2 |
| Compras (T06) | Compra con 2 líneas en `PENDIENTE` que no mueve el inventario; documento repetido y compra sin líneas rechazados; caja no recibe (403); al recibir el inventario sube +5 y +3 y el kárdex registra la `ENTRADA`; recibir dos veces (409); un ajuste no puede dejar existencia negativa | 10 |
| Usuarios y roles | Alta, el usuario entra con su clave; usuario repetido (409, mensaje claro), clave corta y sin roles (400); cambio de roles y de clave (la vieja deja de servir); un usuario desactivado no puede entrar **y su sesión abierta deja de valer (401)**; un administrador no puede desactivarse ni quitarse su propio rol | 11 |
| Catálogos y auditoría (T14) | Alta de repuesto, categoría, tipo de equipo, marca, proveedor y bodega; código repetido y categoría inexistente con mensaje claro; precio negativo o con 3 decimales (400); recepción sin permiso (403); el cambio de precio no altera el total de una factura ya emitida | 9 |
| Dashboard y reportes | 9 indicadores del dashboard; órdenes abiertas = órdenes no cerradas de la lista; los 12 reportes responden con datos; la trazabilidad (12) trae pagos; el historial por serie (3) muestra la orden | 17 |

### 4.1 Cómo repetirla

Contra cualquier API conectada a una **base de prueba** (`TechCare_<nombre>`; la prueba crea datos): `python backend/pruebas/prueba_api_e2e.py http://localhost:5080` (clave de los usuarios de prueba por omisión). Termina con código 1 si algo falla.

### 4.2 Reportes: cumplimiento de la sección 5.1 (`database/pruebas/verificar_reportes_5_1.sql`)

Revisa el catálogo de la base (solo lee): cuenta las tablas reales que alcanza cada reporte, directamente o por las vistas y funciones que usa, los `LEFT JOIN` y busca `SELECT *` y `DISTINCT` en el código (ignora comentarios). Evidencia: `docs/evidencia_pruebas/reportes_5_1.txt`.

| Requisito del enunciado | Mínimo | Resultado |
| --- | --- | --- |
| Reportes que involucran 6 o más tablas | 4 | **9** (reportes 1, 2, 3, 4, 5, 8, 9, 10 y 12) |
| Reportes con `LEFT JOIN` necesario y justificado | 3 | **5** (1, 2, 3, 9 y 12) |
| `SELECT *` o `DISTINCT` en los reportes | 0 | **0** |

## 5. Pruebas de la aplicación web

Además de los scripts, cada pantalla se probó al revisar su PR con la API real (permisos de `rol_app`) y la web compilada, en Chrome automatizado (Playwright), y se repitió un recorrido en la URL pública:

| Flujo | Resultado |
| --- | --- |
| Taller (PR #36): orden de RECIBIDO a factura con `tecnico1`, `recepcion1` y `caja1` | ✅ Diagnóstico → autoriza → iniciar → usar 2 repuestos (la pantalla avisa si se pide más de lo que hay) → actividad → finalizar → factura de Q 896.00 = (180 + 2 × 310) × 1.12 |
| Rechazo del cliente | ✅ La orden pasa a LISTO y caja la entrega sin factura (no hubo reparación) |
| Caja y acciones de la orden (PR #28–#34) | ✅ Facturar con NIT opcional, pago parcial y total, anular con motivo, entrega bloqueada con saldo; los datos coinciden en SQL |
| Inventario, kárdex, compras (PR #15, #19) | ✅ Ajuste, compra y recepción mueven el stock y aparecen en el kárdex; 0 saltos, 0 descuadres |
| Permisos por rol | ✅ Cada rol ve solo su menú y sus botones (por ejemplo, recepción no entra a `/compras`, técnico no ve caja, bodega no ve el taller) |
| Inicio con resumen del taller (PR #41) | ✅ Las 9 cifras coinciden con `vw_DashboardResumen` para los 5 roles; cada tarjeta lleva a `/ordenes?estado=…`; celular sin desbordes |
| Clientes, equipos y nueva orden (PR #43) | ✅ Cliente con ñ y tildes, 2 equipos, validaciones antes de enviar, búsqueda, edición; la orden creada queda en `RECIBIDO` con su historial; técnico, bodega y caja no entran |
| Usuarios (PR #45, API del #42) | ✅ Alta, roles, cambio de clave, desactivación (la sesión abierta se cierra), usuario repetido y quitarse el propio rol rechazados con mensaje |
| Catálogos (PR #47, API del #44 y #46) | ✅ Las 6 pestañas: alta, edición y desactivación; la descripción y la dirección se conservan al editar; el cambio de precio queda en la auditoría con el usuario; el inventario no se toca |
| Recorrido en https://techcare-api-grupo-bhl.azurewebsites.net (`v1.0.1`) | ✅ 5 roles, reportes 1–12, caja, órdenes y trazabilidad, celular; consola del navegador sin errores |

## 6. Hallazgos durante las pruebas

| Hallazgo | Acción |
| --- | --- |
| Un administrador podía quitarse su propio rol ADMINISTRADOR (o dejar el sistema sin administrador activo) | Corregido en `UsuariosController`: se rechaza con 400 y siempre debe quedar un administrador activo |
| Un usuario desactivado conservaba su sesión hasta 8 horas (el token seguía valiendo) | Corregido: el API revisa en cada petición que el usuario siga `ACTIVO` y responde 401 si no |
| Un NIT, serie, código o usuario repetido mostraba "La operación incumple una regla de integridad de los datos" | Corregido en `SqlErrorMiddleware`: un mensaje claro por restricción ("Ya existe un cliente con ese NIT."), y otro para llaves foráneas y CHECK |
| Los roles de un usuario quedan fijos dentro de su token: un cambio de roles no se refleja hasta que la sesión vence (8 h) | Documentado, sin corregir: no afecta reglas ni datos; se resuelve volviendo a iniciar sesión |
| Se acepta un repuesto con precio de venta menor al de compra | Documentado: el enunciado no lo prohíbe; es decisión de negocio |
| I08: un pago escrito directo en SQL podía superar el total (R12 solo lo validaba `sp_RegistrarPago`) | Corregido con `trg_Pago_NoExcedeTotal` (PR #38); I08 e I18 ahora dan 51011 e I19–I20 confirman que los pagos válidos siguen entrando |
| `T03_flujo_reparacion.sql` revisa una orden creada a mano en la base personal de B | T03 se probó por la API sobre la base de prueba (sección 2) |
| Las fechas se guardan con `SYSDATETIME()` y el servidor (Docker, Azure SQL) está en UTC | Lo registrado después de las 18:00 de Guatemala aparece con la fecha del día siguiente; documentado en el manual técnico, no afecta reglas ni totales |
