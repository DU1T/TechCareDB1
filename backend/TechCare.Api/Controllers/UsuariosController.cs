
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
        if (string.IsNullOrWhiteSpace(username) ||
            username.Trim().Length > 50)
            return "Ingrese un username valido (maximo 50 caracteres).";

        if (string.IsNullOrWhiteSpace(nombre) ||
            nombre.Trim().Length > 120)
            return "Ingrese el nombre completo (maximo 120 caracteres).";

        if ((email?.Length ?? 0) > 120 ||
            (telefono?.Length ?? 0) > 20)
            return "Revise la longitud del correo o telefono.";

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

        if (string.IsNullOrWhiteSpace(dto.Password) ||
            dto.Password.Length < 8)
            return BadRequest(new
            {
                error = "La contraseña debe tener al menos 8 caracteres."
            });

        dto.Username = dto.Username!.Trim();
        dto.NombreCompleto = dto.NombreCompleto!.Trim();
        dto.Email = string.IsNullOrWhiteSpace(dto.Email)
            ? null : dto.Email.Trim();
        dto.Telefono = string.IsNullOrWhiteSpace(dto.Telefono)
            ? null : dto.Telefono.Trim();

        try
        {
            var id = await _repo.CrearAsync(
                dto, _passwords.Hash(dto.Password));

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

        if (dto.Password is not null &&
            dto.Password.Length < 8)
            return BadRequest(new
            {
                error = "La nueva contraseña debe tener al menos 8 caracteres."
            });

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
