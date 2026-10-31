import { CLIENTES, ahora } from '../../utils/simuladoClientes'
// API SIMULADA de POST /clientes (repite las reglas de la API: 50203 NIT repetido, etc.)
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const b = await readBody(event)
  if (CLIENTES.some((c) => c.nit.toUpperCase() === String(b.nit).toUpperCase() && c.nit.toUpperCase() !== 'CF'))
    throw createError({ statusCode: 409, data: { error: 'Ya existe un cliente con ese NIT.' } })
  const c = { idCliente: Math.max(...CLIENTES.map((x) => x.idCliente)) + 1, tipoCliente: b.tipoCliente, nit: b.nit, nombre: b.nombre, telefono: b.telefono ?? null, email: b.email ?? null, direccion: b.direccion ?? null, estado: 'ACTIVO', fechaRegistro: ahora() }
  CLIENTES.push(c)
  return { idCliente: c.idCliente, nombre: c.nombre }
})
