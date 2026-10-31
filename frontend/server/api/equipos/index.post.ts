import { CLIENTES, EQUIPOS, MARCAS, TIPOS, ahora } from '../../utils/simuladoClientes'
// API SIMULADA de POST /equipos (número de serie único)
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const b = await readBody(event)
  if (EQUIPOS.some((e) => e.numeroSerie.toLowerCase() === String(b.numeroSerie).toLowerCase()))
    throw createError({ statusCode: 409, data: { error: 'Ya existe un equipo con ese número de serie.' } })
  const e = {
    idEquipo: Math.max(...EQUIPOS.map((x) => x.idEquipo)) + 1, idCliente: b.idCliente,
    cliente: CLIENTES.find((c) => c.idCliente === b.idCliente)?.nombre ?? '',
    idTipoEquipo: b.idTipoEquipo, tipoEquipo: TIPOS.find((t) => t.idTipoEquipo === b.idTipoEquipo)?.nombre ?? '',
    idMarca: b.idMarca, marca: MARCAS.find((m) => m.idMarca === b.idMarca)?.nombre ?? '',
    modelo: b.modelo, numeroSerie: b.numeroSerie, descripcion: b.descripcion ?? null, estado: 'ACTIVO', fechaRegistro: ahora(),
  }
  EQUIPOS.push(e)
  return { idEquipo: e.idEquipo }
})
