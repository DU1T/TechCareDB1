
using Microsoft.AspNetCore.Identity;

namespace TechCare.Api.Auth;

public sealed class PasswordService
{
    private readonly PasswordHasher<object> _hasher = new();

    public string Hash(string password)
    {
        return _hasher.HashPassword(new object(), password);
    }

    public bool Verify(string password, string passwordHash)
    {
        if (string.IsNullOrWhiteSpace(password) ||
            string.IsNullOrWhiteSpace(passwordHash))
        {
            return false;
        }

        try
        {
            var resultado = _hasher.VerifyHashedPassword(
                new object(),
                passwordHash,
                password);

            return resultado != PasswordVerificationResult.Failed;
        }
        catch (FormatException)
        {
            return false;
        }
        catch (ArgumentException)
        {
            return false;
        }
    }
}
