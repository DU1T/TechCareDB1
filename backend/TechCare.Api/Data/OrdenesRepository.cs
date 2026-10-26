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
}