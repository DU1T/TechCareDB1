/*
  Reglas de formato que se repiten en varios formularios. Son las mismas que valida la API
  (backend/TechCare.Api/Validacion.cs): aquí solo sirven para avisar antes de enviar.
  Los largos máximos son los de las columnas de la base (database/02_tablas.sql).
*/

export const LIMITE = {
  usuario: 50,
  passwordMin: 8,
  passwordMax: 128,
  busqueda: 100,
  montoMax: 1_000_000,
  cantidadMax: 10_000,
} as const

/** «12 / 500»: para el hint de los campos de texto largos */
export function contador(texto: string | null | undefined, max: number) {
  return `${(texto ?? '').length} / ${max}`
}

/** 3 a 50 caracteres: letras, números, punto, guion y guion bajo (sin espacios) */
export function errorUsuario(usuario: string) {
  const u = usuario.trim()
  if (!u) return 'Escribe el nombre de usuario.'
  if (!/^[A-Za-z0-9._-]{3,50}$/.test(u)) return 'De 3 a 50 caracteres: letras, números, punto, guion o guion bajo, sin espacios.'
  return ''
}

export function errorPassword(password: string) {
  if (password.length < LIMITE.passwordMin || password.length > LIMITE.passwordMax)
    return `Entre ${LIMITE.passwordMin} y ${LIMITE.passwordMax} caracteres.`
  if (!/\p{L}/u.test(password) || !/\d/.test(password)) return 'Debe tener al menos una letra y un número.'
  return ''
}

/** CF o NIT guatemalteco: dígitos, guion opcional y dígito verificador (número o K) */
export function nitValido(nit: string) {
  return /^(CF|[0-9]{1,12}-?[0-9K])$/i.test(nit.trim())
}

/** Opcional. Si viene: hasta 20 caracteres, al menos 8 dígitos; solo números, espacios, +, -, ( y ) */
export function telefonoValido(telefono: string) {
  const t = telefono.trim()
  if (!t) return true
  return t.length <= 20 && /^[0-9+()\- ]+$/.test(t) && (t.match(/\d/g)?.length ?? 0) >= 8
}

/** Opcional. Si viene: 13 dígitos (se aceptan espacios entre grupos) */
export function dpiValido(dpi: string) {
  const t = dpi.trim()
  if (!t) return true
  return /^[0-9 ]+$/.test(t) && (t.match(/\d/g)?.length ?? 0) === 13
}

export const MENSAJE = {
  nit: 'Escribe CF o el NIT con su dígito verificador (ej. 1234567-8 o 123456-K).',
  telefono: 'Al menos 8 dígitos; solo números, espacios, +, - o paréntesis.',
  dpi: 'El DPI tiene 13 dígitos.',
  monto: 'De Q 0 a Q 1,000,000.',
  cantidad: 'De 1 a 10,000.',
} as const
