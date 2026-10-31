
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Auth;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize(Policy = "USUARIO_GESTIONAR")]
public sealed class UsuariosController : ControllerBase
{
    private readonly UsuariosRepository _repo;
    private readonly PasswordService _passwords;

    public UsuariosController(
        UsuariosRepository repo,
        PasswordService passwords)
    {
        _repo = repo;
        _passwords = passwords;
    }

    [HttpGet("roles")]
    public async Task<IActionResult> Roles()
        => Ok(await _repo.RolesAsync());

    [HttpGet("usuarios")]
    public async Task<IActionResult> Usuarios()
        => Ok(await _repo.ListarAsync());

    [HttpGet("usuarios/{id:int}")]
    public async Task<IActionResult> Detalle(int id)
    {
        if (id <= 0)
            return BadRequest(new
            {
                error = "El ID debe ser positivo."
            });

        var usuario = await _repo.DetalleAsync(id);

        return usuario is null
            ? NotFound(new { error = "El usuario no existe." })
            : Ok(usuario);
    }

    private static string? Validar(
        string? username,
        string? nombre,
        string? email,
        string? telefono,
        List<int>? roles)
    {
        if (!Validacion.UsuarioValido(username))
            return "El usuario debe tener de 3 a 50 caracteres: letras, números, punto, guion o guion bajo, sin espacios.";

        if (string.IsNullOrWhiteSpace(nombre) ||
            nombre.Trim().Length > 120)
            return "Ingrese el nombre completo (maximo 120 caracteres).";

        if ((email?.Length ?? 0) > 120 ||
            (telefono?.Length ?? 0) > 20)
            return "Revise la longitud del correo o telefono.";

        if (!Validacion.TelefonoValido(telefono))
            return "El teléfono debe tener al menos 8 dígitos y solo números, espacios, +, - o paréntesis.";

        if (roles is null ||
            roles.Count == 0 ||
            roles.Any(r => r <= 0))
            return "Debe asignar al menos un rol valido.";

        return null;
    }

    [HttpPost("usuarios")]
    public async Task<IActionResult> Crear(
        CrearUsuarioDto dto)
    {
        var error = Validar(
            dto.Username, dto.NombreCompleto,
            dto.Email, dto.Telefono, dto.IdRoles);

        if (error is not null)
            return BadRequest(new { error });

        var errorPassword = Validacion.ErrorPassword(dto.Password);
        if (errorPassword is not null)
            return BadRequest(new { error = errorPassword });

        dto.Username = dto.Username!.Trim();
        dto.NombreCompleto = dto.NombreCompleto!.Trim();
        dto.Email = string.IsNullOrWhiteSpace(dto.Email)
            ? null : dto.Email.Trim();
        dto.Telefono = string.IsNullOrWhiteSpace(dto.Telefono)
            ? null : dto.Telefono.Trim();

        try
        {
            var id = await _repo.CrearAsync(
                dto, _passwords.Hash(dto.Password!)); // ErrorPassword ya garantizó que no es null

            return Ok(await _repo.DetalleAsync(id));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPut("usuarios/{id:int}")]
    public async Task<IActionResult> Actualizar(
        int id,
        ActualizarUsuarioDto dto)
    {
        if (id <= 0)
            return BadRequest(new { error = "El ID debe ser positivo." });

        var error = Validar(
            dto.Username, dto.NombreCompleto,
            dto.Email, dto.Telefono, dto.IdRoles);

        if (error is not null)
            return BadRequest(new { error });

        dto.Estado = dto.Estado?.Trim().ToUpperInvariant();

        if (dto.Estado is not ("ACTIVO" or "INACTIVO"))
            return BadRequest(new
            {
                error = "El estado debe ser ACTIVO o INACTIVO."
            });

        if (dto.Estado == "INACTIVO" &&
            id == User.IdUsuario())
            return BadRequest(new
            {
                error = "No puede desactivar su propio usuario."
            });

        // Nadie se quita su propio rol de Administrador y nunca se queda el sistema sin un administrador activo
        var idAdmin = await _repo.IdRolAdministradorAsync();
        var seguiraAdmin = dto.Estado == "ACTIVO" &&
            dto.IdRoles!.Contains(idAdmin);

        if (id == User.IdUsuario() &&
            !dto.IdRoles!.Contains(idAdmin))
            return BadRequest(new
            {
                error = "No puede quitarse su propio rol de Administrador."
            });

        if (!seguiraAdmin &&
            await _repo.OtrosAdministradoresActivosAsync(id) == 0)
            return BadRequest(new
            {
                error = "Debe quedar al menos un administrador activo."
            });

        if (dto.Password is not null &&
            Validacion.ErrorPassword(dto.Password) is { } errorNueva)
            return BadRequest(new { error = errorNueva });

        dto.Username = dto.Username!.Trim();
        dto.NombreCompleto = dto.NombreCompleto!.Trim();
        dto.Email = string.IsNullOrWhiteSpace(dto.Email)
            ? null : dto.Email.Trim();
        dto.Telefono = string.IsNullOrWhiteSpace(dto.Telefono)
            ? null : dto.Telefono.Trim();

        string? hash = dto.Password is null
            ? null : _passwords.Hash(dto.Password);

        try
        {
            bool actualizado = await _repo.ActualizarAsync(
                id, dto, hash);

            if (!actualizado)
                return NotFound(new
                {
                    error = "El usuario no existe."
                });

            return Ok(await _repo.DetalleAsync(id));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}
