using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/facturas")]
[Authorize(Policy = "PAGO_REGISTRAR")]
public sealed class PagosController : ControllerBase
{
    private readonly FacturacionRepository _repo;

    public PagosController(FacturacionRepository repo)
    {
        _repo = repo;
    }

    // POST /api/facturas/{id}/pagos
    [HttpPost("{id:int}/pagos")]
    public async Task<IActionResult> RegistrarPago(
        int id,
        [FromBody] RegistrarPagoDto dto)
    {
        if (id <= 0 ||
            dto.IdMetodoPago is null or <= 0 ||
            dto.Monto is null or <= 0 ||
            (dto.Referencia?.Length ?? 0) > 60)
        {
            return BadRequest(new
            {
                error = "Revise la factura, el metodo de pago, el monto y la referencia."
            });
        }

        var resultado = await _repo.RegistrarPagoAsync(
            id,
            dto.IdMetodoPago.Value,
            dto.Monto.Value,
            User.IdUsuario(),
            dto.Referencia?.Trim());

        return Ok(resultado);
    }
}