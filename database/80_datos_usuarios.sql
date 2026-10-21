/* Usuarios de prueba TechCare - Generados desde .NET */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Base de datos incorrecta.', 16, 1);
    SET NOEXEC ON;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'administrador1'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('administrador1', 'AQAAAAIAAYagAAAAEOhbS8xyIUORlzIhxvWmFRv/EAAnh/K9+7qMnrnstkmQ/Od/h9T6JfBMsADjQUcTKA==', N'Administrador Uno');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'administrador1'
  AND r.nombre = 'ADMINISTRADOR'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'administrador2'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('administrador2', 'AQAAAAIAAYagAAAAEJGTYcnZU/dHtdZmw7+eYMSpcu1spO9GRcPfXFN0v+p8yLe1CIsz7n0WrkRe3UistA==', N'Administrador Dos');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'administrador2'
  AND r.nombre = 'ADMINISTRADOR'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'recepcion1'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('recepcion1', 'AQAAAAIAAYagAAAAEMb9Lxy/oIVdaAZq2ZJscU92ydJ9mtLuT+oYk70t5w53b9QS/pjGpycdoaO7Zl3E+w==', N'Recepcionista Uno');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'recepcion1'
  AND r.nombre = 'RECEPCION'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'recepcion2'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('recepcion2', 'AQAAAAIAAYagAAAAEPiTUbBm9zbrn0OXVcmCdQruzL23sCe6rXdyQ3Nz6/WDTvtWMguIXGssAwTouZj5UA==', N'Recepcionista Dos');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'recepcion2'
  AND r.nombre = 'RECEPCION'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'tecnico1'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('tecnico1', 'AQAAAAIAAYagAAAAEPTWAJiID7irRF45rXkU/u4/cflZzQo2fJX855/MOfXk+iQctOQ2pPRt9rozfMopEg==', N'Tecnico Uno');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'tecnico1'
  AND r.nombre = 'TECNICO'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'tecnico2'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('tecnico2', 'AQAAAAIAAYagAAAAEEGJxJ/MoqBvpqd9H+82GMNPzp6ZFfF+6eAA7+SNjOnnMDbxk9KAuErPBI6j4MJOPg==', N'Tecnico Dos');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'tecnico2'
  AND r.nombre = 'TECNICO'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'bodega1'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('bodega1', 'AQAAAAIAAYagAAAAEDBIpDBxPHpxDbJnpwqZSZiazLOI8Pko71Rn2QufoOvH5/QB/i5t7N2T/Keru7y4rA==', N'Bodeguero Uno');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'bodega1'
  AND r.nombre = 'BODEGA'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'bodega2'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('bodega2', 'AQAAAAIAAYagAAAAEMO2jNLaTt030gKwlOfc+j1LDW6g5u/Iwns9bgkMB0cx4v7tlRda1blBlOzRp6T82A==', N'Bodeguero Dos');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'bodega2'
  AND r.nombre = 'BODEGA'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'caja1'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('caja1', 'AQAAAAIAAYagAAAAENagS9goxqV9klXYNjgkS2QB4BWCXkXAHjHbIVtC4TawPqREpVEaL3Z0B22oCm1UQQ==', N'Cajero Uno');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'caja1'
  AND r.nombre = 'CAJA'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Usuario
    WHERE username = 'caja2'
)
BEGIN
    INSERT INTO dbo.Usuario
        (username, passwordHash, nombreCompleto)
    VALUES
        ('caja2', 'AQAAAAIAAYagAAAAEFlH9fOzmYHUbDWaT0kUy7PYGZ6T3KkV61D2axQMXJAcY/FQunAPebNDMwbXIMuguA==', N'Cajero Dos');
END;

INSERT INTO dbo.UsuarioRol (idUsuario, idRol)
SELECT u.idUsuario, r.idRol
FROM dbo.Usuario AS u
CROSS JOIN dbo.Rol AS r
WHERE u.username = 'caja2'
  AND r.nombre = 'CAJA'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.UsuarioRol AS ur
      WHERE ur.idUsuario = u.idUsuario
        AND ur.idRol = r.idRol
  );

SET NOEXEC OFF;
GO
