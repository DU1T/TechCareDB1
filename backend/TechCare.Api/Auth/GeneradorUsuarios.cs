using Microsoft.AspNetCore.Identity;

namespace TechCare.Api.Auth;

public static class GeneradorUsuarios
{
    public static void Generar(TextWriter salida)
    {
        var usuarios = new (string Username, string Nombre, string Rol)[]
        {
            ("administrador1", "Administrador Uno", "ADMINISTRADOR"),
            ("administrador2", "Administrador Dos", "ADMINISTRADOR"),
            ("recepcion1", "Recepcionista Uno", "RECEPCION"),
            ("recepcion2", "Recepcionista Dos", "RECEPCION"),
            ("tecnico1", "Tecnico Uno", "TECNICO"),
            ("tecnico2", "Tecnico Dos", "TECNICO"),
            ("bodega1", "Bodeguero Uno", "BODEGA"),
            ("bodega2", "Bodeguero Dos", "BODEGA"),
            ("caja1", "Cajero Uno", "CAJA"),
            ("caja2", "Cajero Dos", "CAJA")
        };

        // Contraseña de demostración acordada por el equipo.
        // Nunca se escribe directamente en el SQL generado.
        const string clavePrueba = "Demo2026!";

        var hasher = new PasswordHasher<object>();
        var usuarioParaHash = new object();

        static string Sql(string texto)
        {
            return texto.Replace("'", "''");
        }

        salida.WriteLine(
            "/* Usuarios de prueba TechCare - Generados desde .NET */");

        salida.WriteLine(
            "IF DB_NAME() NOT LIKE N'TechCare%'");

        salida.WriteLine("BEGIN");
        salida.WriteLine(
            "    RAISERROR(N'Base de datos incorrecta.', 16, 1);");
        salida.WriteLine("    SET NOEXEC ON;");
        salida.WriteLine("END");
        salida.WriteLine("GO");
        salida.WriteLine();

        foreach (var usuario in usuarios)
        {
            string hash = hasher.HashPassword(
                usuarioParaHash,
                clavePrueba
            );

            string username = Sql(usuario.Username);
            string nombre = Sql(usuario.Nombre);
            string rol = Sql(usuario.Rol);

            salida.WriteLine($"""
                IF NOT EXISTS (
                    SELECT 1
                    FROM dbo.Usuario
                    WHERE username = '{username}'
                )
                BEGIN
                    INSERT INTO dbo.Usuario
                        (username, passwordHash, nombreCompleto)
                    VALUES
                        ('{username}', '{Sql(hash)}', N'{nombre}');
                END;

                INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
                SELECT u.idUsuario, r.idRol
                FROM dbo.Usuario AS u
                CROSS JOIN dbo.Rol AS r
                WHERE u.username = '{username}'
                  AND r.nombre = '{rol}'
                  AND NOT EXISTS (
                      SELECT 1
                      FROM dbo.UsuarioRol AS ur
                      WHERE ur.idUsuario = u.idUsuario
                        AND ur.idRol = r.idRol
                  );

                """);
        }

        salida.WriteLine("SET NOEXEC OFF;");
        salida.WriteLine("GO");
    }
}