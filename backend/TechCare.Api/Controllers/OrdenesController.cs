
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/ordenes")]
[Authorize]
public sealed class OrdenesController : ControllerBase
{
    private readonly OrdenesRepository _repo;

    public OrdenesController(OrdenesRepository repo)
    {
        _repo = repo;
    }

    [HttpGet]
    [Authorize(Policy = "REPORTE_VER")]
    public IActionResult Listar(
        [FromQuery] string? estado,
        [FromQuery] string? prioridad,
        [FromQuery] int? idTecnico)
        => Pendiente();

    [HttpGet("{id:int}")]
    [Authorize(Policy = "REPORTE_VER")]
    public IActionResult Detalle(int id)
        => Pendiente();

    [HttpPost]
    [Authorize(Policy = "ORDEN_CREAR")]
    public async Task<IActionResult> Crear(CrearOrdenDto dto)
    {
        if (dto.IdEquipo <= 0 ||
            string.IsNullOrWhiteSpace(dto.ProblemaReportado) ||
            dto.ProblemaReportado.Length > 500 ||
            (dto.Observaciones?.Length ?? 0) > 500 ||
            string.IsNullOrWhiteSpace(dto.Prioridad))
        {
            return BadRequest(new
            {
                error = "Revise el equipo, problema, prioridad y observaciones."
            });
        }

        var resultado = await _repo.CrearAsync(
            dto,
            User.IdUsuario());

        return Ok(resultado);
    }

    [HttpPost("{id:int}/diagnostico")]
    [Authorize(Policy = "DIAGNOSTICO_REGISTRAR")]
    public async Task<IActionResult> Diagnostico(
        int id,
        RegistrarDiagnosticoDto dto)
    {
        if (id <= 0 ||
            string.IsNullOrWhiteSpace(dto.Descripcion) ||
            dto.Descripcion.Length > 1000 ||
            dto.CostoManoObraEstimado < 0)
        {
            return BadRequest(new
            {
                error = "Los datos del diagnóstico no son válidos."
            });
        }

        var resultado = await _repo.DiagnosticoAsync(
            id,
            User.IdUsuario(),
            dto);

        return Ok(resultado);
    }

    [HttpPost("{id:int}/autorizacion")]
    [Authorize(Policy = "ORDEN_CAMBIAR_ESTADO")]
    public IActionResult Autorizacion(
        int id,
        RegistrarAutorizacionDto dto)
        => Pendiente();

    [HttpPost("{id:int}/reparacion")]
    [Authorize(Policy = "REPARACION_GESTIONAR")]
    public IActionResult IniciarReparacion(
        int id,
        IniciarReparacionDto dto)
        => Pendiente();

    private ObjectResult Pendiente()
        => StatusCode(501, new
        {
            error = "Endpoint pendiente de implementación."
        });
}
