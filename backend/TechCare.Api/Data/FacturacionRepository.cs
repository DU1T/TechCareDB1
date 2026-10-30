
using System.Data;
using Dapper;

namespace TechCare.Api.Data;

public sealed class FacturacionRepository
{
    private readonly SqlConnectionFactory _db;

    public FacturacionRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    // Facturas disponibles para la pantalla de Caja.
// conSaldo=true devuelve solo facturas emitidas con saldo pendiente.
public async Task<IEnumerable<dynamic>> ListarFacturasAsync(
    bool conSaldo)
{
    await using var cn = _db.Create();

    const string sql = """
        SELECT
            idFactura,
            numeroFactura,
            fechaEmision,
            numeroOrden,
            cliente,
            nitFacturacion,
            total,
            totalPagado,
            saldo,
            estadoPago
        FROM dbo.vw_FacturasSaldo
        WHERE
            @conSaldo = 0
            OR (
                estadoFactura = 'EMITIDA'
                AND saldo > 0
            )
        ORDER BY fechaEmision DESC, idFactura DESC;
        """;

    return await cn.QueryAsync(
        sql,
        new { conSaldo });
}

    // Solo metodos de pago activos.
    public async Task<IEnumerable<dynamic>> MetodosPagoAsync()
    {
        await using var cn = _db.Create();

        const string sql = """
            SELECT
                idMetodoPago,
                nombre,
                requiereReferencia
            FROM dbo.MetodoPago
            WHERE estado = 'ACTIVO'
            ORDER BY idMetodoPago;
            """;

        return await cn.QueryAsync(sql);
    }

    // Emitir factura de una orden LISTO
    public async Task<object> FacturarOrdenAsync(
        int idOrden,
        int idUsuario,
        string? nitFacturacion,
        string? nombreFacturacion,
        string? direccionFacturacion)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_FacturarOrden",
            new
            {
                idOrden,
                idUsuario,
                nitFacturacion,
                nombreFacturacion,
                direccionFacturacion
            },
            commandType: CommandType.StoredProcedure);
    }

    // Registrar pago de una factura
    public async Task<object> RegistrarPagoAsync(
        int idFactura,
        int idMetodoPago,
        decimal monto,
        int idUsuario,
        string? referencia)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_RegistrarPago",
            new
            {
                idFactura,
                idMetodoPago,
                monto,
                idUsuario,
                referencia
            },
            commandType: CommandType.StoredProcedure);
    }

    // Anular pago conservando el registro
    public async Task<object> AnularPagoAsync(
        int idPago,
        int idUsuario,
        string motivo)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_AnularPago",
            new
            {
                idPago,
                idUsuario,
                motivo
            },
            commandType: CommandType.StoredProcedure);
    }

    // Registrar entrega y cerrar orden
    public async Task<object> EntregarOrdenAsync(
        int idOrden,
        int idUsuarioEntrega,
        string nombreRecibe,
        string? documentoRecibe,
        string? observaciones)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_EntregarOrden",
            new
            {
                idOrden,
                idUsuarioEntrega,
                nombreRecibe,
                documentoRecibe,
                observaciones
            },
            commandType: CommandType.StoredProcedure);
    }
}
