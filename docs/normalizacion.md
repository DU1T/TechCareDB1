# Normalización del modelo TechCare

Este documento explica por qué las 32 tablas de TechCare están en **tercera forma normal (3FN)** y dónde, a propósito, se guardan datos repetidos. Todos los ejemplos salen de `database/02_tablas.sql`, así que coinciden con lo que está en la base. El diagrama ER está en `docs/ER_TechCare.png` (y `.pdf`).

## Idea base: dependencia funcional

Normalizar es acomodar las columnas para que **cada dato se guarde en un solo lugar**. Si un dato está en dos lugares, tarde o temprano alguien cambia uno y no el otro, y la base queda contradiciéndose.

La herramienta para decidir dónde va cada columna es la **dependencia funcional**: `A → B` quiere decir que conocer `A` basta para saber `B`. Por ejemplo, `idRepuesto → nombre`: dado el repuesto, su nombre es uno solo. La regla general es que una columna vive en la tabla cuya llave la determina.

Si una tabla no está normalizada, aparecen tres problemas (se llaman *anomalías*):

- **De actualización:** el mismo dato está en varias filas y hay que cambiarlo en todas.
- **De inserción:** no se puede guardar un dato sin inventar otro (por ejemplo, registrar un repuesto sin tener inventario).
- **De borrado:** al borrar una fila se pierde un dato que no tenía que ver.

## Primera forma normal (1FN)

**Regla:** cada celda guarda un solo valor y no hay grupos repetidos de columnas.

**Ejemplo en TechCare:** los repuestos que usa una reparación van en `DetalleRepuesto`, **una fila por repuesto usado**, con su bodega, cantidad y precio.

**Cómo sería mal:**

| idReparacion | repuestos |
| --- | --- |
| 7 | `RAM-001 x2, SSD-004 x1` |

Con esa columna no se puede descontar el stock de cada repuesto, ni sumar cuánto se usó de `RAM-001` por técnico o por bodega (reporte 5), ni poner una FK que impida escribir un código que no existe. Con columnas `repuesto1`, `repuesto2`, `repuesto3` pasa lo mismo y además hay un límite fijo.

**También se cumple en:**

- Roles: un usuario con dos roles tiene dos filas en `UsuarioRol`, no `roles = 'TECNICO,BODEGA'`.
- Factura: cada concepto cobrado es una línea de `DetalleFactura`.
- Compra: cada repuesto pedido es una línea de `DetalleCompra`.
- Avance de una reparación: cada actividad es una fila de `ActividadReparacion`.

## Segunda forma normal (2FN)

**Regla:** estar en 1FN y, si la llave primaria es **compuesta** (de varias columnas), que cada columna dependa de la llave **completa** y no solo de una parte.

**Ejemplo en TechCare:** `Inventario` tiene la llave `(idBodega, idRepuesto)`.

- `existencia` depende de las dos: el mismo repuesto tiene 12 unidades en una bodega y 3 en otra.
- `stockMinimo` también: cada bodega fija su propio mínimo.
- El `nombre` y el `precioVenta` dependen **solo** de `idRepuesto`, por eso viven en `Repuesto` y no en `Inventario`.

**Cómo sería mal:** guardar `nombreRepuesto` en `Inventario`.

| idBodega | idRepuesto | nombreRepuesto | existencia |
| --- | --- | --- | --- |
| 1 | 5 | Memoria RAM 8 GB | 12 |
| 2 | 5 | Memoria RAM 8GB DDR4 | 3 |

El mismo repuesto termina con dos nombres (anomalía de actualización). Además, no se podría dar de alta un repuesto nuevo sin meterlo en una bodega (anomalía de inserción).

**Las demás tablas con llave compuesta también cumplen:**

| Tabla | Llave | Columnas que dependen de la llave completa |
| --- | --- | --- |
| `DetalleCompra` | `(idCompra, idRepuesto)` | `cantidad`, `costoUnitario` (cuánto y a qué costo se compró **ese** repuesto en **esa** compra) |
| `UsuarioRol` | `(idUsuario, idRol)` | `fechaAsignacion` |
| `ActividadReparacion` | `(idReparacion, numeroActividad)` | `idTecnico`, `descripcion`, `horas` (cada actividad la puede hacer un técnico distinto) |
| `DetalleFactura` | `(idFactura, numeroLinea)` | `tipoLinea`, `descripcion`, `cantidad`, `precioUnitario` |
| `RolPermiso`, `TransicionEstado` | dos columnas | solo tienen la llave: no hay nada que pueda depender de una parte |

Las tablas con llave de una sola columna (`idCliente`, `idOrden`, …) cumplen la 2FN automáticamente, porque su llave no tiene "partes".

## Tercera forma normal (3FN)

**Regla:** estar en 2FN y que ninguna columna dependa de **otra columna que no sea llave**. A esto se le llama *dependencia transitiva*: `llave → X → Y`; en ese caso `Y` debe vivir en la tabla de `X`.

**Ejemplo en TechCare:** `OrdenServicio` **no** guarda `idCliente`. La cadena es `OrdenServicio → Equipo → Cliente`: la orden apunta al equipo y el equipo sabe de quién es. El comentario en `02_tablas.sql` lo dice: *"El cliente se obtiene por Equipo.idCliente (3FN: no se duplica en la orden)"*.

**Cómo sería mal:** agregar `OrdenServicio.idCliente`.

| idOrden | idEquipo | idCliente |
| --- | --- | --- |
| 15 | 9 (del cliente 4) | 7 |

Nada impide que la orden diga "cliente 7" mientras el equipo es del cliente 4. ¿A quién se le factura? La base quedaría contradiciéndose.

**El mismo criterio se repite en el modelo:**

- `Reparacion` no guarda `idOrden`: se llega por `Diagnostico` (`Reparacion → Diagnostico → OrdenServicio`). Así, además, una reparación no puede existir sin diagnóstico (R04).
- `DetalleRepuesto` no guarda la orden ni el cliente: se llega por la reparación.
- `Equipo` guarda `idMarca` e `idTipoEquipo`, no el texto de la marca. El nombre de la marca depende de la marca, no del equipo.
- `Repuesto` guarda `idCategoria`; el nombre de la categoría vive en `CategoriaRepuesto`.
- `Compra` guarda `idProveedor`; el NIT y el teléfono del proveedor viven en `Proveedor`.
- `Pago` guarda `idMetodoPago`; si el método exige referencia (`requiereReferencia`) se sabe por `MetodoPago`.

## Un paso más: forma normal de Boyce-Codd (FNBC)

La FNBC pide que **todo lo que determina otra columna sea una llave candidata**. Una llave candidata es cualquier columna, o grupo de columnas, que identifica la fila sin repetirse. En TechCare, las columnas que determinan a otras son la llave primaria o tienen `UNIQUE`:

- `Equipo.numeroSerie` (`UQ_Equipo_NumeroSerie`)
- `Repuesto.codigo`, `Bodega.codigo`, `Proveedor.nit`, `Usuario.username`
- `Factura (serie, numero)`
- `Compra (idProveedor, numeroDocumento)`
- `Cliente.nit` cuando no es `CF`: índice único filtrado `UX_Cliente_Nit` en `03_indices.sql`, porque muchos consumidores finales comparten `CF`.

Por eso el modelo también cumple la FNBC.

## Datos repetidos a propósito (desnormalizaciones justificadas)

Normalizar no significa no repetir nunca nada. En estos casos se guarda un dato que se podría calcular, por una razón concreta, y **siempre con algo que impide que se contradiga**:

| Dato guardado | Se podría calcular con | Por qué se guarda | Qué lo protege |
| --- | --- | --- | --- |
| `Inventario.existencia` | La suma de entradas menos salidas del kárdex (`MovimientoInventario`) | Consultar el stock es instantáneo. Hay **una fila que bloquear** (`UPDLOCK`), para que dos técnicos no se lleven la última unidad a la vez. Y un `CHECK` impide negativos (R10). | `CK_Inventario_Existencia`. Solo cambia por los SP de `42`, dentro de una transacción que también escribe el kárdex. `techcare_app` no tiene permiso de `UPDATE` directo (da error 230). La consulta de cuadre de abajo da 0 descuadres. |
| `MovimientoInventario.existenciaAnterior` y `existenciaResultante` | El movimiento anterior | Cada fila del kárdex se puede revisar sola, sin recorrer todo el historial. | `CK_Movimiento_Cuadre`: anterior ± cantidad = resultante. El trigger `trg_MovimientoInventario_Inmutable` impide editarlo o borrarlo (R14). |
| `Inventario.fechaUltimoMovimiento` | `MAX(fechaMovimiento)` del kárdex | La pantalla de inventario (`vw_InventarioActual`) muestra cuándo se movió cada repuesto sin recorrer el kárdex. | La escriben los mismos SP que escriben el movimiento, en la misma transacción. |
| `OrdenServicio.estado` | La última fila de `HistorialEstadoOrden` | Filtrar órdenes por estado es de las consultas más usadas (lista de órdenes, tablero). | El trigger `trg_OrdenServicio_Estado` escribe el historial con cada cambio y valida la transición contra `TransicionEstado`. |
| `Factura.subtotal`, `impuesto` y `total` | La suma de `DetalleFactura` | La factura es un **documento fiscal**: lo emitido no cambia aunque luego cambien los precios (R09). | `CK_Factura_Total` (total = subtotal + impuesto). Una factura no se edita: se anula con motivo (`CK_Factura_Anulacion`). |
| `Factura.nitFacturacion`, `nombreFacturacion` y `direccionFacturacion` | Los datos de `Cliente` (por orden → equipo → cliente) | Si el cliente cambia de dirección, la factura vieja debe seguir mostrando la de ese día. `sp_FacturarOrden` las copia al emitir. | Las copia el SP una sola vez. Si caja manda otro NIT o nombre, se usa ese; si no, los del cliente. |
| `DetalleRepuesto.precioUnitario` y `costoUnitario`; `DetalleCompra.costoUnitario` | `Repuesto.precioVenta` y `precioCompraRef` | Son precios **históricos**: lo que costó ese día. `Repuesto` solo guarda el precio actual. | Los cambios de precio quedan en `AuditoriaPrecioRepuesto` (trigger de `31`). La prueba T14 comprueba que cambiar el precio no altera una factura vieja. |

Las **columnas calculadas** (`computed columns`) no cuentan como dato repetido, porque SQL Server las calcula y nadie las puede escribir a mano:

- `OrdenServicio.numeroOrden` (`'OS-' + idOrden`)
- `DetalleFactura.subtotalLinea` (`cantidad * precioUnitario`)

Se marcan `PERSISTED` (el resultado se guarda en disco; así `numeroOrden` puede llevar `UNIQUE`), pero no se pueden contradecir.

## Cómo comprobar que la existencia cuadra con el kárdex

Esta consulta compara la existencia guardada con la suma de entradas menos salidas. Si el dato repetido está bien protegido, devuelve **0 descuadres**:

```sql
SELECT COUNT(*) AS descuadres
FROM dbo.Inventario i
OUTER APPLY (SELECT SUM(CASE m.tipo WHEN 'ENTRADA' THEN m.cantidad ELSE -m.cantidad END) AS neto
             FROM dbo.MovimientoInventario m
             WHERE m.idBodega = i.idBodega AND m.idRepuesto = i.idRepuesto) x
WHERE i.existencia <> ISNULL(x.neto, 0);
```

## Lo que a propósito **no** se guarda

| Dato | Por qué no | Cómo se obtiene |
| --- | --- | --- |
| Saldo de la factura (R12/R13) | Cambia con cada pago. Si se anula un pago, un saldo guardado quedaría viejo. | `dbo.fn_SaldoFactura(@idFactura)` (total − pagos aplicados) y la vista `vw_FacturasSaldo`. |
| Cliente de la orden | Dependencia transitiva (ver 3FN). | `OrdenServicio → Equipo → Cliente`. |
| Orden de la reparación | Dependencia transitiva. | `Reparacion → Diagnostico → OrdenServicio`. |
| Total de horas de una reparación | Se suma de sus actividades. | `SUM(horas)` en `ActividadReparacion`. |

## Resumen para la defensa

1. **1FN:** una fila por repuesto usado (`DetalleRepuesto`), nunca una lista en una celda.
2. **2FN:** en `Inventario (idBodega, idRepuesto)` la existencia depende de las dos columnas; el nombre depende solo del repuesto y por eso está en `Repuesto`.
3. **3FN:** la orden no guarda el cliente; se llega por el equipo. Si lo guardara, podría contradecir al dueño del equipo.
4. **Repetidos a propósito:** existencia, kárdex, estado actual, totales y precios históricos. Cada uno tiene una razón y algo que lo protege (`CHECK`, transacción, trigger o permisos).
5. **No guardado:** el saldo de la factura, que siempre se calcula.
