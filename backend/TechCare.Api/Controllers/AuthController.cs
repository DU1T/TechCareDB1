
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Auth;
using TechCare.Api.Data;

namespace TechCare.Api.Controllers;

public record LoginDto(string Username, string Password);

public sealed record UsuarioRow(
    int IdUsuario,
    string Username,
    string PasswordHash,
    string NombreCompleto,
    string Estado);

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly SqlConnectionFactory _db;
    private readonly PasswordService _passwords;
    private readonly TokenService _tokens;

    public AuthController(
        SqlConnectionFactory db,
        PasswordService passwords,
        TokenService tokens)
    {
        _db = db;
        _passwords = passwords;
        _tokens = tokens;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(LoginDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) ||
            string.IsNullOrWhiteSpace(dto.Password))
        {
            return BadRequest(new
            {
                error = "Debe ingresar usuario y contraseña."
            });
        }

        await using var cn = _db.Create();

        var usuario = await cn.QuerySingleOrDefaultAsync<UsuarioRow>(
            """
            SELECT
                idUsuario,
                username,
                passwordHash,
                nombreCompleto,
                estado
            FROM dbo.Usuario
            WHERE username = @Username
            """,
            new { dto.Username });

        if (usuario is null ||
            usuario.Estado != "ACTIVO" ||
            !_passwords.Verify(dto.Password, usuario.PasswordHash))
        {
            return Unauthorized(new
            {
                error = "Usuario o contraseña incorrectos."
            });
        }

        var roles = (await cn.QueryAsync<string>(
            """
            SELECT r.nombre
            FROM dbo.UsuarioRol AS ur
            INNER JOIN dbo.Rol AS r
                ON r.idRol = ur.idRol
            WHERE ur.idUsuario = @IdUsuario
            """,
            new { usuario.IdUsuario })).ToList();

        var permisos = (await cn.QueryAsync<string>(
            """
            SELECT DISTINCT p.codigo
            FROM dbo.UsuarioRol AS ur
            INNER JOIN dbo.RolPermiso AS rp
                ON rp.idRol = ur.idRol
            INNER JOIN dbo.Permiso AS p
                ON p.idPermiso = rp.idPermiso
            WHERE ur.idUsuario = @IdUsuario
            """,
            new { usuario.IdUsuario })).ToList();

        string token = _tokens.Crear(
            usuario.IdUsuario,
            usuario.Username,
            usuario.NombreCompleto,
            roles,
            permisos);

        return Ok(new
        {
            token,
            usuario = new
            {
                idUsuario = usuario.IdUsuario,
                nombreCompleto = usuario.NombreCompleto,
                roles,
                permisos
            }
        });
    }
}
    