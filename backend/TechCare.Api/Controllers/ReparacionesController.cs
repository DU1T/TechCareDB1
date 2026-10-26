
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/reparaciones")]
[Authorize]
public sealed class ReparacionesController : ControllerBase
{
    private readonly OrdenesRepository _repo;

    public ReparacionesController(OrdenesRepository repo)
    {
        _repo = repo;
    }

    [HttpPost("{id:int}/actividades")]
    [Authorize(Policy = "REPARACION_GESTIONAR")]
    public async Task<IActionResult> RegistrarActividad(
        int id,
        RegistrarActividadDto dto)
    {
        if (id <= 0 ||
            string.IsNullOrWhiteSpace(dto.Descripcion) ||
            dto.Descripcion.Length > 300 ||
            dto.Horas <= 0 ||
            dto.Horas > 24)
        {
            return BadRequest(new
            {
                error = "Revise la descripcion y las horas de la actividad."
            });
        }

        var resultado = await _repo.RegistrarActividadAsync(
            id,
            User.IdUsuario(),
            dto);

        return Ok(resultado);
    }

    [HttpPost("{id:int}/finalizar")]
    [Authorize(Policy = "REPARACION_GESTIONAR")]
    public async Task<IActionResult> Finalizar(
        int id,
        FinalizarReparacionDto dto)
    {
        if (id <= 0 ||
            string.IsNullOrWhiteSpace(dto.DescripcionTrabajo) ||
            dto.DescripcionTrabajo.Length > 1000 ||
            dto.CostoManoObra < 0)
        {
            return BadRequest(new
            {
                error = "Revise la descripcion y el costo de mano de obra."
            });
        }

        var resultado = await _repo.FinalizarReparacionAsync(
            id,
            User.IdUsuario(),
            dto);

        return Ok(resultado);
    }
}
