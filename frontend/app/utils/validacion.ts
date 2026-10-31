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

/**
  Hint de un campo corto: el texto base y, cuando lo escrito llega al 80 % del máximo, el contador
  («45 / 50»), para que quede claro por qué el campo deja de aceptar letras.
*/
export function limite(texto: string | null | undefined, max: number, base?: string) {
  const n = (texto ?? '').length
  const partes = [base, n >= Math.ceil(max * 0.8) ? `${n} / ${max}` : ''].filter(Boolean)
  return partes.length ? partes.join(' · ') : undefined
}

/** Caracteres que un campo no acepta: si se escribe uno, el aviso sale al instante */
export const INVALIDO = {
  usuario: /[^A-Za-z0-9._-]/,
  telefono: /[^0-9+()\- ]/,
  dpi: /[^0-9 ]/,
  nit: /[^0-9KkCcFf-]/,
  codigo: /[^A-Za-z0-9._\/-]/,
  nombre: /[^\p{L}\p{N} .,'&()\/-]/u,
  referencia: /[^A-Za-z0-9 ._\/-]/,
} as const

/**
  Cuándo mostrar el error de un campo:
  - después de intentar guardar, siempre;
  - antes, solo si ya se escribió un carácter que el campo no acepta (por ejemplo, un espacio en el usuario).
  Lo incompleto (un teléfono a medias, un campo vacío) se avisa al guardar, no mientras se escribe.
*/
export function mostrar(intento: boolean, error: string | undefined | null, valor?: unknown, invalido?: RegExp) {
  if (!error) return undefined
  if (intento) return error
  return invalido && invalido.test(String(valor ?? '')) ? error : undefined
}

/** Nombre de persona o empresa: letras, números, espacios y . , ' & ( ) - /, con al menos 2 letras */
export function errorNombre(valor: string, max: number, obligatorio = true) {
  const t = valor.trim()
  if (!t) return obligatorio ? 'Escribe el nombre.' : ''
  if (valor.length > max) return `Máximo ${max} caracteres.`
  if (INVALIDO.nombre.test(t)) return 'Solo letras, números, espacios y . , \' & ( ) - /'
  if ((t.match(/\p{L}/gu)?.length ?? 0) < 2) return 'Escribe al menos 2 letras.'
  return ''
}

/** Correo con forma nombre@dominio.ext */
export function emailValido(email: string) {
  const t = email.trim()
  return !t || /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(t)
}

/** Código, número de serie o de documento: sin espacios; letras, números y . _ - / */
export function codigoValido(codigo: string) {
  return /^[A-Za-z0-9._\/-]+$/.test(codigo.trim())
}

/** Referencia de pago: letras, números, espacios y . _ - / */
export function referenciaValida(ref: string) {
  const t = ref.trim()
  return !t || /^[A-Za-z0-9 ._\/-]+$/.test(t)
}

/** Monto con a lo más 2 decimales */
export function dosDecimales(n: number) {
  return Math.round(n * 100) / 100 === n
}

/** 3 a 50 caracteres: letras, números, punto, guion y guion bajo (sin espacios) */
export function errorUsuario(usuario: string) {
  const u = usuario.trim()
  if (!u) return 'Escribe el nombre de usuario.'
  if (INVALIDO.usuario.test(u) || /\s/.test(usuario)) return 'Sin espacios ni tildes: solo letras, números, punto, guion o guion bajo.'
  if (u.length < 3) return 'Mínimo 3 caracteres.'
  if (u.length > LIMITE.usuario) return `Máximo ${LIMITE.usuario} caracteres.`
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
  email: 'Escribe un correo como nombre@dominio.com.',
  codigo: 'Sin espacios: solo letras, números y . _ - /',
  referencia: 'Solo letras, números, espacios y . _ - /',
  decimales: 'Máximo 2 decimales.',
} as const
