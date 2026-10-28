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

    // Consulta el detalle completo de una orden y su historial.
    public async Task<object?> DetalleAsync(int idOrden)
    {
        await using var cn = _db.Create();

        using var resultados = await cn.QueryMultipleAsync(
            "dbo.sp_DetalleOrden",
            new { idOrden },
            commandType: CommandType.StoredProcedure);

        // Primer conjunto: datos de la orden
        var orden = await resultados.ReadFirstOrDefaultAsync<dynamic>();

        // Segundo conjunto: historial de estados
        var historial = (await resultados.ReadAsync<dynamic>()).ToList();

        if (orden is null)
        {
            return null;
        }

        return new
        {
            orden,
            historial
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