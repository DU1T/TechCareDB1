using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize(Policy = "PAGO_REGISTRAR")]
public sealed class CajaConsultasController : ControllerBase
{
    private readonly FacturacionRepository _repo;

    public CajaConsultasController(FacturacionRepository repo)
    {
        _repo = repo;
    }

    // GET /api/facturas?conSaldo=true
    [HttpGet("facturas")]
    public async Task<IActionResult> Facturas(
        [FromQuery] bool conSaldo = false)
    {
        var resultado = await _repo.ListarFacturasAsync(
            conSaldo);

        return Ok(resultado);
    }

    // GET /api/metodos-pago
    [HttpGet("metodos-pago")]
    public async Task<IActionResult> MetodosPago()
    {
        var resultado = await _repo.MetodosPagoAsync();

        return Ok(resultado);
    }
}