using TechCare.Api.Auth;
using TechCare.Api.Data;
using TechCare.Api.Middleware;

using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Microsoft.AspNetCore.Mvc;

//80. generador de usuarios
if (args.Length > 0 &&
    args[0].Equals(
        "generar-usuarios",
        StringComparison.OrdinalIgnoreCase))
{
    GeneradorUsuarios.Generar(Console.Out);
    return;
}



var builder = WebApplication.CreateBuilder(args);

// Add services to the container.


builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            var errores = context.ModelState
                .Where(x => x.Value?.Errors.Count > 0)
                .SelectMany(x => x.Value!.Errors)
                .Select(e => e.ErrorMessage)
                .ToList();

            bool jsonMalFormado = context.ModelState.Any(x =>
                x.Key.StartsWith("$", StringComparison.Ordinal));

            string mensaje;

            if (jsonMalFormado)
            {
                mensaje = "El cuerpo de la solicitud contiene un JSON inválido.";
            }
            else if (errores.Count > 0)
            {
                mensaje = "Faltan datos obligatorios o la solicitud contiene valores inválidos.";
            }
            else
            {
                mensaje = "La solicitud no es válida.";
            }

            return new BadRequestObjectResult(new
            {
                error = mensaje
            });
        };
});


builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<OrdenesRepository>();
builder.Services.AddScoped<InventarioRepository>();
builder.Services.AddScoped<ReportesRepository>();
builder.Services.AddScoped<ClientesEquiposRepository>();

builder.Services.AddSingleton<PasswordService>();
builder.Services.AddSingleton<TokenService>();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle


builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Introduce el token JWT de TechCare."
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var config = builder.Configuration;

var jwtKey = config["Jwt:Key"]
    ?? throw new InvalidOperationException(
        "No se configuró Jwt:Key.");

if (Encoding.UTF8.GetByteCount(jwtKey) < 64)
{
    throw new InvalidOperationException(
        "La clave JWT debe tener al menos 64 bytes.");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters =
            new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = config["Jwt:Issuer"],

                ValidateAudience = true,
                ValidAudience = config["Jwt:Audience"],

                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(jwtKey)),

                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            };
            options.Events = new JwtBearerEvents
            {
                OnChallenge = async context =>
                {
                    context.HandleResponse();

                    if (context.Response.HasStarted)
                        return;

                    context.Response.StatusCode =
                        StatusCodes.Status401Unauthorized;

                    await context.Response.WriteAsJsonAsync(new
                    {
                        error = "Debe iniciar sesión para continuar."
                    });
                },

                OnForbidden = async context =>
                {
                    if (context.Response.HasStarted)
                        return;

                    context.Response.StatusCode =
                        StatusCodes.Status403Forbidden;

                    await context.Response.WriteAsJsonAsync(new
                    {
                        error = "No tiene permiso para realizar esta acción."
                    });
                }
            };

    }
);

string[] permisos =
[
    "USUARIO_GESTIONAR",
    "CLIENTE_GESTIONAR",
    "ORDEN_CREAR",
    "ORDEN_CAMBIAR_ESTADO",
    "DIAGNOSTICO_REGISTRAR",
    "REPARACION_GESTIONAR",
    "REPUESTO_CONSUMIR",
    "CATALOGO_GESTIONAR",
    "COMPRA_REGISTRAR",
    "COMPRA_RECIBIR",
    "FACTURA_EMITIR",
    "PAGO_REGISTRAR",
    "ENTREGA_REGISTRAR",
    "REPORTE_VER"
];

builder.Services.AddAuthorization(options =>
{
    foreach (var permiso in permisos)
    {
        options.AddPolicy(
            permiso,
            policy => policy
                .RequireAuthenticatedUser()
                .RequireClaim("permiso", permiso));
    }
});

    builder.Services.AddCors(options =>
{
    options.AddPolicy("front", policy =>
    {
        policy
            .WithOrigins("http://localhost:3000")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();
app.UseMiddleware<SqlErrorMiddleware>();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Web de Nuxt servida por la misma API (una sola URL: sin CORS y el mismo
// build sirve en Azure y en la demo en LAN). deploy/publicar.ps1 la copia a wwwroot.
app.UseDefaultFiles();
app.UseStaticFiles();

app.UseCors("front");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Una ruta /api que no existe responde 404 en JSON; cualquier otra ruta
// (/ordenes/15, /caja…) devuelve index.html para que la resuelva el SPA.
app.Map("/api/{**resto}", () =>
    Results.NotFound(new { error = "La ruta solicitada no existe." }));
app.MapFallbackToFile("index.html");

app.Run();
