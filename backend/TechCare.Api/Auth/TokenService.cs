
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace TechCare.Api.Auth;

public sealed class TokenService
{
    private readonly IConfiguration _configuration;

    public TokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string Crear(
        int idUsuario,
        string username,
        string nombre,
        IEnumerable<string> roles,
        IEnumerable<string> permisos)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, idUsuario.ToString()),
            new(ClaimTypes.Name, username),
            new("nombre", nombre)
        };

        claims.AddRange(
            roles.Select(r => new Claim(ClaimTypes.Role, r)));

        claims.AddRange(
            permisos.Select(p => new Claim("permiso", p)));

        string jwtKey = _configuration["Jwt:Key"]
            ?? throw new InvalidOperationException(
                "No se configuró Jwt:Key.");

        if (Encoding.UTF8.GetByteCount(jwtKey) < 64)
        {
            throw new InvalidOperationException(
                "La clave JWT debe tener al menos 64 bytes.");
        }

        string issuer = _configuration["Jwt:Issuer"]
            ?? throw new InvalidOperationException(
                "No se configuró Jwt:Issuer.");

        string audience = _configuration["Jwt:Audience"]
            ?? throw new InvalidOperationException(
                "No se configuró Jwt:Audience.");

        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtKey));

        var credentials = new SigningCredentials(
            key,
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: DateTime.UtcNow.AddHours(8),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
