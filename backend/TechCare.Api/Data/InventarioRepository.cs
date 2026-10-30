// Inventario, compras y catálogos de C.
// Las lecturas usan vistas, reportes o SELECT parametrizados; todo lo que
// mueve existencias pasa por los SP (techcare_app no puede tocar esas tablas).
using System.Data;
using Dapper;
using TechCare.Api.Dtos;

namespace TechCare.Api.Data;

public sealed class InventarioRepository
{
    private readonly SqlConnectionFactory _db;

    public InventarioRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    public async Task<IEnumerable<dynamic>> InventarioAsync(
        int? idBodega,
        int? idCategoria,
        string? estadoStock)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT v.idBodega, v.codigoBodega, v.bodega,
                   v.idRepuesto, v.codigo, v.repuesto,
                   v.idCategoria, v.categoria,
                   v.existencia, v.stockMinimo,
                   v.precioCompraRef, v.precioVenta, v.valorInventario,
                   v.estadoStock, v.fechaUltimoMovimiento
            FROM dbo.vw_InventarioActual AS v
            WHERE (@idBodega IS NULL OR v.idBodega = @idBodega)
              AND (@idCategoria IS NULL OR v.idCategoria = @idCategoria)
              AND (@estadoStock IS NULL OR v.estadoStock = @estadoStock)
            ORDER BY v.bodega, v.categoria, v.codigo;
            """,
            new { idBodega, idCategoria, estadoStock });
    }

    public async Task<IEnumerable<dynamic>> KardexAsync(
        int? idBodega,
        int? idRepuesto,
        DateOnly? fechaInicio,
        DateOnly? fechaFin)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_09_Kardex",
            new
            {
                idBodega,
                idRepuesto,
                fechaInicio = fechaInicio?.ToDateTime(TimeOnly.MinValue),
                fechaFin = fechaFin?.ToDateTime(TimeOnly.MinValue)
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<object> AjusteAsync(
        AjusteInventarioDto dto,
        int idUsuario)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_AjusteInventario",
            new
            {
                idBodega = dto.IdBodega,
                idRepuesto = dto.IdRepuesto,
                cantidad = dto.Cantidad,
                idUsuario,
                motivo = dto.Motivo
            },
            commandType: CommandType.StoredProcedure);
    }

    // Consumo de un repuesto en una reparación: detalle + salida + movimiento en una transacción (R06, R07, R09)
    public async Task<object> UtilizarRepuestoAsync(
        int idReparacion,
        UtilizarRepuestoDto dto,
        int idUsuario)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_UtilizarRepuesto",
            new
            {
                idReparacion,
                idBodega = dto.IdBodega,
                idRepuesto = dto.IdRepuesto,
                cantidad = dto.Cantidad,
                idUsuario
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<dynamic>> ComprasAsync(
        string? estado,
        int? idProveedor)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT c.idCompra, c.numeroDocumento, c.fechaCompra, c.estado,
                   c.idProveedor, p.nombre AS proveedor,
                   c.idBodegaDestino, b.nombre AS bodegaDestino,
                   reg.nombreCompleto AS registradaPor,
                   c.fechaRecepcion, rec.nombreCompleto AS recibidaPor,
                   c.observaciones,
                   d.lineas, d.total
            FROM dbo.Compra AS c
            INNER JOIN dbo.Proveedor AS p ON p.idProveedor = c.idProveedor
            INNER JOIN dbo.Bodega AS b ON b.idBodega = c.idBodegaDestino
            INNER JOIN dbo.Usuario AS reg ON reg.idUsuario = c.idUsuarioRegistro
            LEFT JOIN dbo.Usuario AS rec ON rec.idUsuario = c.idUsuarioRecepcion
            CROSS APPLY (
                SELECT COUNT(*) AS lineas,
                       CAST(SUM(dc.cantidad * dc.costoUnitario) AS DECIMAL(14,2)) AS total
                FROM dbo.DetalleCompra AS dc
                WHERE dc.idCompra = c.idCompra
            ) AS d
            WHERE (@estado IS NULL OR c.estado = @estado)
              AND (@idProveedor IS NULL OR c.idProveedor = @idProveedor)
            ORDER BY c.fechaCompra DESC, c.idCompra DESC;
            """,
            new { estado, idProveedor });
    }

    public async Task<object> CrearCompraAsync(
        CrearCompraDto dto,
        int idUsuario)
    {
        // Las líneas viajan como parámetro de tabla (dbo.TipoDetalleCompra):
        // la compra y su detalle se guardan en una sola transacción del SP.
        var detalle = new DataTable();
        detalle.Columns.Add("idRepuesto", typeof(int));
        detalle.Columns.Add("cantidad", typeof(int));
        detalle.Columns.Add("costoUnitario", typeof(decimal));

        foreach (var linea in dto.Lineas!)
        {
            detalle.Rows.Add(
                linea.IdRepuesto,
                linea.Cantidad,
                linea.CostoUnitario);
        }

        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_RegistrarCompra",
            new
            {
                idProveedor = dto.IdProveedor,
                idBodegaDestino = dto.IdBodegaDestino,
                numeroDocumento = dto.NumeroDocumento,
                idUsuario,
                detalle = detalle.AsTableValuedParameter("dbo.TipoDetalleCompra"),
                observaciones = dto.Observaciones
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<object> RecibirCompraAsync(
        int idCompra,
        int idUsuario)
    {
        await using var cn = _db.Create();

        // sp_RecibirCompra no devuelve filas: si termina sin THROW, quedó RECIBIDA
        await cn.ExecuteAsync(
            "dbo.sp_RecibirCompra",
            new { idCompra, idUsuario },
            commandType: CommandType.StoredProcedure);

        return new { idCompra, estado = "RECIBIDA" };
    }

    public async Task<IEnumerable<dynamic>> BodegasAsync()
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT idBodega, codigo, nombre, ubicacion, estado
            FROM dbo.Bodega
            ORDER BY nombre;
            """);
    }

    public async Task<IEnumerable<dynamic>> CategoriasAsync()
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT idCategoria, nombre
            FROM dbo.CategoriaRepuesto
            ORDER BY nombre;
            """);
    }

    public async Task<IEnumerable<dynamic>> ProveedoresAsync()
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT idProveedor, nit, nombre, contacto, telefono, email, estado
            FROM dbo.Proveedor
            ORDER BY nombre;
            """);
    }

    public async Task<IEnumerable<dynamic>> RepuestosAsync(int? idCategoria)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT r.idRepuesto, r.codigo, r.nombre,
                   r.idCategoria, c.nombre AS categoria,
                   r.precioCompraRef, r.precioVenta, r.estado
            FROM dbo.Repuesto AS r
            INNER JOIN dbo.CategoriaRepuesto AS c ON c.idCategoria = r.idCategoria
            WHERE (@idCategoria IS NULL OR r.idCategoria = @idCategoria)
            ORDER BY r.codigo;
            """,
            new { idCategoria });
    }

    public async Task<IEnumerable<dynamic>> TecnicosAsync()
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT u.idUsuario, u.nombreCompleto
            FROM dbo.Usuario AS u
            WHERE u.estado = 'ACTIVO'
              AND EXISTS (SELECT 1
                          FROM dbo.UsuarioRol AS ur
                          INNER JOIN dbo.Rol AS r ON r.idRol = ur.idRol
                          WHERE ur.idUsuario = u.idUsuario AND r.nombre = 'TECNICO')
            ORDER BY u.nombreCompleto;
            """);
    }
}
