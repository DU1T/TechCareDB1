using System.Text.RegularExpressions;

namespace TechCare.Api;

// Reglas de formato y topes compartidas por los controladores.
// La web repite las mismas reglas en frontend/app/utils/validacion.ts (solo para avisar antes);
// las que valen son estas y las de la base de datos.
public static partial class Validacion
{
    // Topes que evitan desbordar DECIMAL(12,2) e INT en los cálculos de la factura (que respondería 500)
    public const decimal MontoMaximo = 1_000_000m;
    public const int CantidadMaxima = 10_000;

    public const int PasswordMinimo = 8;
    public const int PasswordMaximo = 128;

    // 3 a 50 caracteres: letras, números, punto, guion y guion bajo (sin espacios)
    [GeneratedRegex(@"^[A-Za-z0-9._-]{3,50}$")]
    private static partial Regex UsuarioRegex();

    // CF o NIT guatemalteco: dígitos, guion opcional y dígito verificador (número o K)
    [GeneratedRegex(@"^(CF|[0-9]{1,12}-?[0-9K])$", RegexOptions.IgnoreCase)]
    private static partial Regex NitRegex();

    // Solo dígitos, espacios, +, -, ( y )
    [GeneratedRegex(@"^[0-9+()\- ]+$")]
    private static partial Regex TelefonoRegex();

    public static bool UsuarioValido(string? usuario)
        => usuario is not null && UsuarioRegex().IsMatch(usuario.Trim());

    public static string? ErrorPassword(string? password)
    {
        if (string.IsNullOrEmpty(password) ||
            password.Length < PasswordMinimo ||
            password.Length > PasswordMaximo)
            return $"La contraseña debe tener entre {PasswordMinimo} y {PasswordMaximo} caracteres.";

        if (!password.Any(char.IsLetter) || !password.Any(char.IsDigit))
            return "La contraseña debe tener al menos una letra y un número.";

        return null;
    }

    public static bool NitValido(string? nit)
        => nit is not null && nit.Length <= 15 && NitRegex().IsMatch(nit.Trim());

    // Opcional: vacío es válido. Si viene, de 8 a 20 caracteres y al menos 8 dígitos.
    public static bool TelefonoValido(string? telefono)
    {
        if (string.IsNullOrWhiteSpace(telefono)) return true;
        var t = telefono.Trim();
        return t.Length <= 20 &&
               TelefonoRegex().IsMatch(t) &&
               t.Count(char.IsDigit) >= 8;
    }

    // DPI opcional: si viene, 13 dígitos (se aceptan espacios entre grupos)
    public static bool DpiValido(string? dpi)
    {
        if (string.IsNullOrWhiteSpace(dpi)) return true;
        var t = dpi.Trim();
        return t.Length <= 20 &&
               t.All(c => char.IsDigit(c) || c == ' ') &&
               t.Count(char.IsDigit) == 13;
    }

    public static bool MontoValido(decimal? monto)
        => monto is >= 0 and <= MontoMaximo;
}
