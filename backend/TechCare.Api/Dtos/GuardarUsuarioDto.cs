
namespace TechCare.Api.Dtos;

public sealed class CrearUsuarioDto
{
    public string? Username { get; set; }
    public string? Password { get; set; }
    public string? NombreCompleto { get; set; }
    public string? Email { get; set; }
    public string? Telefono { get; set; }
    public List<int>? IdRoles { get; set; }
}

public sealed class ActualizarUsuarioDto
{
    public string? Username { get; set; }
    public string? Password { get; set; }
    public string? NombreCompleto { get; set; }
    public string? Email { get; set; }
    public string? Telefono { get; set; }
    public string? Estado { get; set; }
    public List<int>? IdRoles { get; set; }
}
