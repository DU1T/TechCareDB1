
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
    public async Task<IActionResult> Listar(
        [FromQuery] string? estado,
        [FromQuery] string? prioridad,
        [FromQuery] int? idTecnico)
    {
        estado = string.IsNullOrWhiteSpace(estado)
            ? null
            : estado.Trim();

        prioridad = string.IsNullOrWhiteSpace(prioridad)
            ? null
            : prioridad.Trim();

        if ((estado?.Length ?? 0) > 25 ||
            (prioridad?.Length ?? 0) > 10 ||
            idTecnico <= 0)
        {
            return BadRequest(new
            {
                error = "Revise los filtros de estado, prioridad y tecnico."
            });
        }

        var resultado = await _repo.ListarAsync(
            estado,
            prioridad,
            idTecnico);

        return Ok(resultado);
    }

    [HttpGet("{id:int}")]
    [Authorize(Policy = "REPORTE_VER")]
    public async Task<IActionResult> Detalle(int id)
    {
        if (id <= 0)
        {
            return BadRequest(new
            {
                error = "El identificador de la orden debe ser mayor que cero."
            });
        }

        var resultado = await _repo.DetalleAsync(id);

        if (resultado is null)
        {
            return NotFound(new
            {
                error = "La orden solicitada no existe."
            });
        }

        return Ok(resultado);
    }

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
    public async Task<IActionResult> Autorizacion(
        int id,
        RegistrarAutorizacionDto dto)
    {
        if (id <= 0 || dto.Autorizado is null)
        {
            return BadRequest(new
            {
                error = "Debe indicar una orden valida y si el cliente autoriza."
            });
        }

        var resultado = await _repo.AutorizarAsync(
            id,
            dto.Autorizado.Value,
            User.IdUsuario());

        return Ok(resultado);
    }

    [HttpPost("{id:int}/reparacion")]
    [Authorize(Policy = "REPARACION_GESTIONAR")]
    public async Task<IActionResult> IniciarReparacion(int id)
    {
        if (id <= 0)
        {
            return BadRequest(new
            {
                error = "El identificador de la orden no es valido."
            });
        }

        var resultado = await _repo.IniciarReparacionAsync(
            id,
            User.IdUsuario());

        return Ok(resultado);
    }


    private ObjectResult Pendiente()
        => StatusCode(501, new
        {
            error = "Endpoint pendiente de implementación."
        });
}
