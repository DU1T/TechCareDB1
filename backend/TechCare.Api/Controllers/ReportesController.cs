using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/reportes")]
[Authorize(Policy = "REPORTE_VER")]
public sealed class ReportesController : ControllerBase
{
    private readonly ReportesRepository _repo;

    public ReportesController(ReportesRepository repo)
    {
        _repo = repo;
    }

    // GET /api/reportes/1
    // Ordenes activas por estado, prioridad y tecnico
    [HttpGet("1")]
    public async Task<IActionResult> OrdenesActivas(
        [FromQuery] string? estado,
        [FromQuery] string? prioridad,
        [FromQuery] int? idTecnico)
    {
        estado = string.IsNullOrWhiteSpace(estado)
            ? null : estado.Trim();

        prioridad = string.IsNullOrWhiteSpace(prioridad)
            ? null : prioridad.Trim();

        if ((estado?.Length ?? 0) > 25 ||
            (prioridad?.Length ?? 0) > 10 ||
            idTecnico <= 0)
        {
            return BadRequest(new
            {
                error = "Revise los filtros de estado, prioridad y tecnico."
            });
        }

        var resultado = await _repo.OrdenesActivasAsync(
            estado,
            prioridad,
            idTecnico);

        return Ok(resultado);
    }

    // GET /api/reportes/2
    // Historial completo por cliente o NIT
    [HttpGet("2")]
    public async Task<IActionResult> HistorialCliente(
        [FromQuery] int? idCliente,
        [FromQuery] string? nit)
    {
        nit = string.IsNullOrWhiteSpace(nit)
            ? null : nit.Trim();

        if ((idCliente is null && nit is null) ||
            idCliente <= 0 ||
            nit?.Length > 15)
        {
            return BadRequest(new
            {
                error = "Indique un ID de cliente o NIT valido."
            });
        }

        var resultado = await _repo.HistorialClienteAsync(
            idCliente,
            nit);

        return Ok(resultado);
    }

    // GET /api/reportes/3
    // Historial tecnico del equipo
    [HttpGet("3")]
    public async Task<IActionResult> HistorialEquipo(
        [FromQuery] string? numeroSerie)
    {
        if (string.IsNullOrWhiteSpace(numeroSerie) ||
            numeroSerie.Length > 60)
        {
            return BadRequest(new
            {
                error = "Debe indicar un numero de serie valido."
            });
        }

        var resultado = await _repo.HistorialEquipoAsync(
            numeroSerie.Trim());

        return Ok(resultado);
    }

    // GET /api/reportes/4
    // Productividad de tecnicos
    [HttpGet("4")]
    public async Task<IActionResult> ProductividadTecnico(
        [FromQuery] int? idTecnico,
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin)
    {
        if (idTecnico <= 0)
        {
            return BadRequest(new
            {
                error = "El ID del tecnico debe ser mayor que cero."
            });
        }

        if (fechaInicio.HasValue &&
            fechaFin.HasValue &&
            fechaInicio.Value.Date > fechaFin.Value.Date)
        {
            return BadRequest(new
            {
                error = "La fecha inicial no puede ser posterior a la final."
            });
        }

        var resultado = await _repo.ProductividadTecnicoAsync(
            idTecnico,
            fechaInicio?.Date,
            fechaFin?.Date);

        return Ok(resultado);
    }
}