using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
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

    // GET /api/reportes/5
    // Repuestos utilizados por orden, tecnico y bodega
    [HttpGet("5")]
    public async Task<IActionResult> RepuestosUtilizados(
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin,
        [FromQuery] int? idTecnico,
        [FromQuery] int? idBodega)
    {
        if (idTecnico <= 0 || idBodega <= 0)
        {
            return BadRequest(new
            {
                error = "Revise los filtros de tecnico y bodega."
            });
        }

        if (FechasInvertidas(fechaInicio, fechaFin))
        {
            return BadRequest(new
            {
                error = "La fecha inicial no puede ser posterior a la final."
            });
        }

        var resultado = await _repo.RepuestosUtilizadosAsync(
            fechaInicio?.Date,
            fechaFin?.Date,
            idTecnico,
            idBodega);

        return Ok(resultado);
    }

    // GET /api/reportes/6
    // Inventario actual por bodega y categoria
    [HttpGet("6")]
    public async Task<IActionResult> Inventario(
        [FromQuery] int? idBodega,
        [FromQuery] int? idCategoria)
    {
        if (idBodega <= 0 || idCategoria <= 0)
        {
            return BadRequest(new
            {
                error = "Revise los filtros de bodega y categoria."
            });
        }

        var resultado = await _repo.InventarioAsync(
            idBodega,
            idCategoria);

        return Ok(resultado);
    }

    // GET /api/reportes/7
    // Repuestos en o bajo el stock minimo
    [HttpGet("7")]
    public async Task<IActionResult> BajoMinimo(
        [FromQuery] int? idBodega)
    {
        if (idBodega <= 0)
        {
            return BadRequest(new
            {
                error = "El ID de la bodega debe ser mayor que cero."
            });
        }

        var resultado = await _repo.BajoMinimoAsync(idBodega);

        return Ok(resultado);
    }

    // GET /api/reportes/8
    // Compras por proveedor con detalle (incluye pendientes)
    [HttpGet("8")]
    public async Task<IActionResult> ComprasProveedor(
        [FromQuery] int? idProveedor,
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin,
        [FromQuery] string? estado)
    {
        estado = string.IsNullOrWhiteSpace(estado)
            ? null : estado.Trim().ToUpperInvariant();

        if (idProveedor <= 0 ||
            (estado is not null && !EstadosCompra.Contains(estado)))
        {
            return BadRequest(new
            {
                error = "Revise el proveedor y el estado (PENDIENTE, RECIBIDA o ANULADA)."
            });
        }

        if (FechasInvertidas(fechaInicio, fechaFin))
        {
            return BadRequest(new
            {
                error = "La fecha inicial no puede ser posterior a la final."
            });
        }

        var resultado = await _repo.ComprasProveedorAsync(
            idProveedor,
            fechaInicio?.Date,
            fechaFin?.Date,
            estado);

        return Ok(resultado);
    }

    // GET /api/reportes/9
    // Kardex: entradas y salidas con existencia antes y despues
    [HttpGet("9")]
    public async Task<IActionResult> Kardex(
        [FromQuery] int? idBodega,
        [FromQuery] int? idRepuesto,
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin)
    {
        if (idBodega <= 0 || idRepuesto <= 0)
        {
            return BadRequest(new
            {
                error = "Revise los filtros de bodega y repuesto."
            });
        }

        if (FechasInvertidas(fechaInicio, fechaFin))
        {
            return BadRequest(new
            {
                error = "La fecha inicial no puede ser posterior a la final."
            });
        }

        var resultado = await _repo.KardexAsync(
            idBodega,
            idRepuesto,
            fechaInicio?.Date,
            fechaFin?.Date);

        return Ok(resultado);
    }

    // GET /api/reportes/10
    // Facturas con saldo y sus pagos
    [HttpGet("10")]
    public async Task<IActionResult> FacturasSaldo(
        [FromQuery] int? idCliente,
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin,
        [FromQuery] bool incluirPagadas = false)
    {
        if (idCliente <= 0 || FechasInvertidas(fechaInicio, fechaFin))
        {
            return BadRequest(new
            {
                error = "Revise el cliente y el rango de fechas."
            });
        }

        var resultado = await _repo.FacturasSaldoAsync(
            incluirPagadas,
            idCliente,
            fechaInicio?.Date,
            fechaFin?.Date);

        return Ok(resultado);
    }

    // GET /api/reportes/11
    // Ingresos por periodo
    [HttpGet("11")]
    public async Task<IActionResult> IngresosPeriodo(
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin)
    {
        if (FechasInvertidas(fechaInicio, fechaFin))
        {
            return BadRequest(new
            {
                error = "La fecha inicial no puede ser posterior a la final."
            });
        }

        var resultado = await _repo.IngresosPeriodoAsync(
            fechaInicio?.Date,
            fechaFin?.Date);

        return Ok(resultado);
    }

    // GET /api/reportes/12?idOrden=3
    // Trazabilidad de una orden: cinco resultados
    [HttpGet("12")]
    public async Task<IActionResult> Trazabilidad(
        [FromQuery] int? idOrden)
    {
        if (idOrden is null or <= 0)
        {
            return BadRequest(new
            {
                error = "Debe indicar un identificador de orden valido."
            });
        }

        try
        {
            var resultado = await _repo.TrazabilidadAsync(
                idOrden.Value);

            return Ok(resultado);
        }
        catch (SqlException ex) when (ex.Number == 50327)
        {
            return NotFound(new
            {
                error = ex.Message
            });
        }
        catch (SqlException ex) when (ex.Number == 50326)
        {
            return BadRequest(new
            {
                error = ex.Message
            });
        }
    }


    private static readonly string[] EstadosCompra =
        ["PENDIENTE", "RECIBIDA", "ANULADA"];

    private static bool FechasInvertidas(
        DateTime? fechaInicio,
        DateTime? fechaFin)
        => fechaInicio.HasValue &&
           fechaFin.HasValue &&
           fechaInicio.Value.Date > fechaFin.Value.Date;
}