
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize(Policy = "REPORTE_VER")]
public sealed class DashboardController : ControllerBase
{
    private readonly SqlConnectionFactory _db;

    public DashboardController(SqlConnectionFactory db)
    {
        _db = db;
    }

    // GET /api/dashboard
    [HttpGet]
    public async Task<IActionResult> Resumen()
    {
        await using var cn = _db.Create();

        const string sql = """
            SELECT
                ordenesAbiertas,
                recibidas,
                enDiagnostico,
                esperandoAutorizacion,
                enReparacion,
                listasParaEntregar,
                facturasConSaldo,
                saldoPorCobrar,
                repuestosBajoMinimo
            FROM dbo.vw_DashboardResumen;
            """;

        var resultado = await cn.QuerySingleAsync(sql);

        return Ok(resultado);
    }
}
