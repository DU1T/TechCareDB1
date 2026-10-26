//Esta clase recupera idUsuario directamente del token

using System.Security.Claims;

namespace TechCare.Api.Middleware;

public static class UserExtensions
{
    public static int IdUsuario(this ClaimsPrincipal user)
    {
        string? valor = user.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (!int.TryParse(valor, out int idUsuario)
            || idUsuario <= 0)
        {
            throw new UnauthorizedAccessException(
                "El token no contiene un usuario válido.");
        }

        return idUsuario;
    }
}