using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Dtos;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/reparaciones")]
[Authorize]
public sealed class ReparacionesController : ControllerBase
{
    [HttpPost("{id:int}/actividades")]
    [Authorize(Policy = "REPARACION_GESTIONAR")]
    public IActionResult RegistrarActividad(
        int id,
        RegistrarActividadDto dto)
        => Pendiente();

    [HttpPost("{id:int}/finalizar")]
    [Authorize(Policy = "REPARACION_GESTIONAR")]
    public IActionResult Finalizar(
        int id,
        FinalizarReparacionDto dto)
        => Pendiente();

    private ObjectResult Pendiente()
        => StatusCode(501, new
        {
            error = "Endpoint pendiente de implementación."
        });
}