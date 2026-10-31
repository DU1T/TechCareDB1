
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize(Policy = "CLIENTE_GESTIONAR")]
public sealed class ClientesEquiposController : ControllerBase
{
    private readonly ClientesEquiposRepository _repo;

    public ClientesEquiposController(
        ClientesEquiposRepository repo)
    {
        _repo = repo;
    }

    [HttpGet("clientes")]
    public async Task<IActionResult> Clientes(
        [FromQuery] string? buscar)
    {
        buscar = string.IsNullOrWhiteSpace(buscar)
            ? null
            : buscar.Trim();

        if (buscar?.Length > 150)
            return BadRequest(new
            {
                error = "El texto de busqueda es demasiado largo."
            });

        return Ok(await _repo.ListarClientesAsync(buscar));
    }

    [HttpGet("clientes/{id:int}")]
    public async Task<IActionResult> Cliente(int id)
    {
        if (id <= 0)
            return BadRequest(new
            {
                error = "El ID del cliente debe ser positivo."
            });

        var cliente = await _repo.DetalleClienteAsync(id);

        return cliente is null
            ? NotFound(new { error = "El cliente no existe." })
            : Ok(cliente);
    }

    [HttpGet("equipos")]
    public async Task<IActionResult> Equipos(
        [FromQuery] int? idCliente)
    {
        if (idCliente <= 0)
            return BadRequest(new
            {
                error = "El ID del cliente debe ser positivo."
            });

        return Ok(await _repo.ListarEquiposAsync(idCliente));
    }

    [HttpGet("equipos/{id:int}")]
    public async Task<IActionResult> Equipo(int id)
    {
        if (id <= 0)
            return BadRequest(new
            {
                error = "El ID del equipo debe ser positivo."
            });

        var equipo = await _repo.DetalleEquipoAsync(id);

        return equipo is null
            ? NotFound(new { error = "El equipo no existe." })
            : Ok(equipo);
    }

    // GET /api/clientes/{id}/equipos
    [HttpGet("clientes/{id:int}/equipos")]
    public async Task<IActionResult> EquiposDelCliente(int id)
    {
        if (id <= 0)
        {
            return BadRequest(new
            {
                error = "El ID del cliente debe ser positivo."
            });
        }

        var cliente = await _repo.DetalleClienteAsync(id);

        if (cliente is null)
        {
            return NotFound(new
            {
                error = "El cliente no existe."
            });
        }

        return Ok(await _repo.ListarEquiposAsync(id));
    }

    // POST /api/clientes
    [HttpPost("clientes")]
    public async Task<IActionResult> CrearCliente(
        [FromBody] GuardarClienteDto dto)
    {
        var error = ValidarCliente(dto);

        if (error is not null)
            return BadRequest(new { error });

        NormalizarCliente(dto);

        return Ok(await _repo.CrearClienteAsync(dto));
    }

    // PUT /api/clientes/{id}
    [HttpPut("clientes/{id:int}")]
    public async Task<IActionResult> ActualizarCliente(
        int id,
        [FromBody] GuardarClienteDto dto)
    {
        if (id <= 0)
            return BadRequest(new
            {
                error = "El ID del cliente debe ser positivo."
            });

        var error = ValidarCliente(dto);

        if (error is not null)
            return BadRequest(new { error });

        NormalizarCliente(dto);

        var resultado = await _repo.ActualizarClienteAsync(
            id, dto);

        return resultado is null
            ? NotFound(new { error = "El cliente no existe." })
            : Ok(resultado);
    }

    // POST /api/equipos
    [HttpPost("equipos")]
    public async Task<IActionResult> CrearEquipo(
        [FromBody] GuardarEquipoDto dto)
    {
        var error = ValidarEquipo(dto);

        if (error is not null)
            return BadRequest(new { error });

        NormalizarEquipo(dto);

        return Ok(await _repo.CrearEquipoAsync(dto));
    }

    // PUT /api/equipos/{id}
    [HttpPut("equipos/{id:int}")]
    public async Task<IActionResult> ActualizarEquipo(
        int id,
        [FromBody] GuardarEquipoDto dto)
    {
        if (id <= 0)
            return BadRequest(new
            {
                error = "El ID del equipo debe ser positivo."
            });

        var error = ValidarEquipo(dto);

        if (error is not null)
            return BadRequest(new { error });

        NormalizarEquipo(dto);

        var resultado = await _repo.ActualizarEquipoAsync(
            id, dto);

        return resultado is null
            ? NotFound(new { error = "El equipo no existe." })
            : Ok(resultado);
    }

    private static string? Limpiar(string? valor)
        => string.IsNullOrWhiteSpace(valor)
            ? null
            : valor.Trim();

    private static string? ValidarCliente(
        GuardarClienteDto dto)
    {
        var tipo = Limpiar(dto.TipoCliente)?.ToUpperInvariant();
        var nit = Limpiar(dto.Nit);
        var nombre = Limpiar(dto.Nombre);
        var telefono = Limpiar(dto.Telefono);
        var email = Limpiar(dto.Email);

        if (tipo is not ("INDIVIDUAL" or "EMPRESA") ||
            nit is null || nit.Length > 15 ||
            nombre is null || nombre.Length > 150)
            return "Revise el tipo de cliente, NIT y nombre.";

        if (!Validacion.NitValido(nit))
            return "El NIT debe ser CF o números con su dígito verificador (por ejemplo 1234567-8 o 123456-K).";

        if (tipo == "EMPRESA" &&
            nit.Equals("CF", StringComparison.OrdinalIgnoreCase))
            return "Una empresa debe tener NIT distinto de CF.";

        if (!Validacion.NombreValido(nombre))
            return "El nombre " + Validacion.MensajeNombre;

        if (telefono is null && email is null)
            return "Debe indicar telefono o correo electronico.";

        if (!Validacion.EmailValido(email))
            return Validacion.MensajeEmail;

        if ((telefono?.Length ?? 0) > 20 ||
            (email?.Length ?? 0) > 120 ||
            (Limpiar(dto.Direccion)?.Length ?? 0) > 250)
            return "Los datos de contacto superan la longitud permitida.";

        if (!Validacion.TelefonoValido(telefono))
            return "El teléfono debe tener al menos 8 dígitos y solo números, espacios, +, - o paréntesis.";

        var estado = Limpiar(dto.Estado)?.ToUpperInvariant();

        if (estado is not null &&
            estado is not ("ACTIVO" or "INACTIVO"))
            return "El estado del cliente no es valido.";

        return null;
    }

    private static void NormalizarCliente(
        GuardarClienteDto dto)
    {
        dto.TipoCliente =
            Limpiar(dto.TipoCliente)?.ToUpperInvariant();

        dto.Nit = Limpiar(dto.Nit);
        dto.Nombre = Limpiar(dto.Nombre);
        dto.Telefono = Limpiar(dto.Telefono);
        dto.Email = Limpiar(dto.Email);
        dto.Direccion = Limpiar(dto.Direccion);
        dto.Estado = Limpiar(dto.Estado)?.ToUpperInvariant();
    }

    private static string? ValidarEquipo(
        GuardarEquipoDto dto)
    {
        if (dto.IdCliente is null or <= 0 ||
            dto.IdTipoEquipo is null or <= 0 ||
            dto.IdMarca is null or <= 0)
            return "Debe indicar cliente, tipo de equipo y marca validos.";

        var modelo = Limpiar(dto.Modelo);
        var serie = Limpiar(dto.NumeroSerie);

        if (modelo is null || modelo.Length > 80 ||
            serie is null || serie.Length > 60 ||
            (Limpiar(dto.Descripcion)?.Length ?? 0) > 300)
            return "Revise el modelo, numero de serie y descripcion.";

        if (!Validacion.CodigoValido(serie))
            return "El número de serie " + Validacion.MensajeCodigo;

        var estado = Limpiar(dto.Estado)?.ToUpperInvariant();

        if (estado is not null &&
            estado is not ("ACTIVO" or "INACTIVO" or "BAJA"))
            return "El estado del equipo no es valido.";

        return null;
    }

    private static void NormalizarEquipo(
        GuardarEquipoDto dto)
    {
        dto.Modelo = Limpiar(dto.Modelo);
        dto.NumeroSerie = Limpiar(dto.NumeroSerie);
        dto.Descripcion = Limpiar(dto.Descripcion);
        dto.Estado = Limpiar(dto.Estado)?.ToUpperInvariant();
    }

}
