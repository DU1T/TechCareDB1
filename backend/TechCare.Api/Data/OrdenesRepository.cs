using System.Data;
using Dapper;
using TechCare.Api.Dtos;

namespace TechCare.Api.Data;

public sealed class OrdenesRepository
{
    private readonly SqlConnectionFactory _db;

    public OrdenesRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    // Consulta general de ordenes
    // Incluye ordenes activas y finalizadas
    public async Task<IEnumerable<dynamic>> ListarAsync(
        string? estado,
        string? prioridad,
        int? idTecnico)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_ListarOrdenes",
            new
            {
                estado,
                prioridad,
                idTecnico
            },
            commandType: CommandType.StoredProcedure);
    }

    // Detalle completo de una orden, historial, factura y entrega.
    public async Task<object?> DetalleAsync(int idOrden)
    {
        await using var cn = _db.Create();

        dynamic? orden;
        List<dynamic> historial;

        // Conservamos los dos resultados del SP existente.
        using (var resultados = await cn.QueryMultipleAsync(
            "dbo.sp_DetalleOrden",
            new { idOrden },
            commandType: CommandType.StoredProcedure))
        {
            orden = await resultados.ReadFirstOrDefaultAsync<dynamic>();

            historial = (await resultados.ReadAsync<dynamic>())
                .ToList();
        }

        if (orden is null)
        {
            return null;
        }

        // Factura y saldo calculado desde la vista oficial.
        const string sqlFactura = """
            SELECT
                idFactura,
                numeroFactura,
                fechaEmision,
                total,
                totalPagado,
                saldo,
                estadoPago
            FROM dbo.vw_FacturasSaldo
            WHERE idOrden = @idOrden;
            """;

        var factura = await cn.QueryFirstOrDefaultAsync(
            sqlFactura,
            new { idOrden });

        // Información de entrega, si la orden ya fue entregada.
        const string sqlEntrega = """
            SELECT
                e.idEntrega,
                e.fechaEntrega,
                e.nombreRecibe,
                e.documentoRecibe,
                e.observaciones,
                u.nombreCompleto AS entregadoPor
            FROM dbo.Entrega AS e
            INNER JOIN dbo.Usuario AS u
                ON u.idUsuario = e.idUsuarioEntrega
            WHERE e.idOrden = @idOrden;
            """;

        var entrega = await cn.QueryFirstOrDefaultAsync(
            sqlEntrega,
            new { idOrden });

        return new
        {
            orden,
            historial,
            factura,
            entrega
        };
    }

    public async Task<object> CrearAsync(
        CrearOrdenDto dto,
        int idUsuario)
    {
        await using var cn = _db.Create();

        var resultado = await cn.QuerySingleAsync(
            "dbo.sp_RegistrarOrdenServicio",
            new
            {
                idEquipo = dto.IdEquipo,
                idUsuarioRecepcion = idUsuario,
                problemaReportado = dto.ProblemaReportado,
                prioridad = dto.Prioridad,
                fechaEstimada = dto.FechaEstimada?
                    .ToDateTime(TimeOnly.MinValue),
                observaciones = dto.Observaciones
            },
            commandType: CommandType.StoredProcedure);

        return resultado;
    }

    public async Task<object> DiagnosticoAsync(
        int idOrden,
        int idTecnico,
        RegistrarDiagnosticoDto dto)
    {
        await using var cn = _db.Create();

        var resultado = await cn.QuerySingleAsync(
            "dbo.sp_RegistrarDiagnostico",
            new
            {
                idOrden,
                idTecnico,
                descripcion = dto.Descripcion,
                costoManoObraEstimado =
                    dto.CostoManoObraEstimado
            },
            commandType: CommandType.StoredProcedure);

        return resultado;
    }

    public async Task<object> AutorizarAsync(
        int idOrden,
        bool autorizado,
        int idUsuario)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_RegistrarAutorizacionCliente",
            new
            {
                idOrden,
                autorizado,
                idUsuario
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<object> IniciarReparacionAsync(
        int idOrden,
        int idTecnico)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_IniciarReparacion",
            new
            {
                idOrden,
                idTecnico
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<object> RegistrarActividadAsync(
        int idReparacion,
        int idTecnico,
        RegistrarActividadDto dto)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_RegistrarActividad",
            new
            {
                idReparacion,
                idTecnico,
                descripcion = dto.Descripcion,
                horas = dto.Horas
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<object> FinalizarReparacionAsync(
        int idReparacion,
        int idTecnico,
        FinalizarReparacionDto dto)
    {
        await using var cn = _db.Create();

        return await cn.QuerySingleAsync(
            "dbo.sp_FinalizarReparacion",
            new
            {
                idReparacion,
                idTecnico,
                descripcionTrabajo = dto.DescripcionTrabajo,
                costoManoObra = dto.CostoManoObra
            },
            commandType: CommandType.StoredProcedure);
    }

}