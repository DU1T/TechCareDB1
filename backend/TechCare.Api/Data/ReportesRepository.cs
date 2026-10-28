using System.Data;
using Dapper;

namespace TechCare.Api.Data;

public sealed class ReportesRepository
{
    private readonly SqlConnectionFactory _db;

    public ReportesRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    // Reporte 1: Ordenes activas
    public async Task<IEnumerable<dynamic>> OrdenesActivasAsync(
        string? estado,
        string? prioridad,
        int? idTecnico)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_01_OrdenesActivas",
            new
            {
                estado,
                prioridad,
                idTecnico
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 2: Historial de cliente
    public async Task<IEnumerable<dynamic>> HistorialClienteAsync(
        int? idCliente,
        string? nit)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_02_HistorialCliente",
            new
            {
                idCliente,
                nit
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 3: Historial tecnico por numero de serie
    public async Task<IEnumerable<dynamic>> HistorialEquipoAsync(
        string numeroSerie)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_03_HistorialEquipo",
            new
            {
                numeroSerie
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 4: Productividad por tecnico
    public async Task<IEnumerable<dynamic>> ProductividadTecnicoAsync(
        int? idTecnico,
        DateTime? fechaInicio,
        DateTime? fechaFin)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_04_ProductividadTecnico",
            new
            {
                idTecnico,
                fechaInicio,
                fechaFin
            },
            commandType: CommandType.StoredProcedure);
    }
}