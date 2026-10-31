// Repuestos usados en una reparación (C). Va aparte de ReparacionesController (B)
// porque el proceso es de inventario: lo resuelve sp_UtilizarRepuesto de 42.
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/reparaciones")]
[Authorize(Policy = "REPUESTO_CONSUMIR")]
public sealed class ReparacionRepuestosController : ControllerBase
{
    private readonly InventarioRepository _repo;

    public ReparacionRepuestosController(InventarioRepository repo)
    {
        _repo = repo;
    }

    // POST /api/reparaciones/{id}/repuestos
    // El SP valida técnico (R03), reparación en proceso, bodega (R06) y stock (R10);
    // si algo falla no queda nada aplicado y el middleware responde 409 con su mensaje.
    [HttpPost("{id:int}/repuestos")]
    public async Task<IActionResult> Utilizar(int id, UtilizarRepuestoDto dto)
    {
        if (id <= 0 ||
            dto.IdBodega <= 0 ||
            dto.IdRepuesto <= 0 ||
            dto.Cantidad <= 0 ||
            dto.Cantidad > Validacion.CantidadMaxima)
        {
            return BadRequest(new
            {
                error = "Indique la reparación, la bodega, el repuesto y una cantidad de 1 a 10,000."
            });
        }

        var resultado = await _repo.UtilizarRepuestoAsync(
            id,
            dto,
            User.IdUsuario());

        return Ok(resultado);
    }
}
