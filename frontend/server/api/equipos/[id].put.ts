import { EQUIPOS, MARCAS, TIPOS } from '../../utils/simuladoClientes'
// API SIMULADA de PUT /equipos/{id}
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const e = EQUIPOS.find((x) => x.idEquipo === Number(getRouterParam(event, 'id')))
  if (!e) throw createError({ statusCode: 404, data: { error: 'Equipo no encontrado.' } })
  const b = await readBody(event)
  if (EQUIPOS.some((x) => x.idEquipo !== e.idEquipo && x.numeroSerie.toLowerCase() === String(b.numeroSerie).toLowerCase()))
    throw createError({ statusCode: 409, data: { error: 'Ya existe un equipo con ese número de serie.' } })
  Object.assign(e, {
    idTipoEquipo: b.idTipoEquipo, tipoEquipo: TIPOS.find((t) => t.idTipoEquipo === b.idTipoEquipo)?.nombre ?? e.tipoEquipo,
    idMarca: b.idMarca, marca: MARCAS.find((m) => m.idMarca === b.idMarca)?.nombre ?? e.marca,
    modelo: b.modelo, numeroSerie: b.numeroSerie, descripcion: b.descripcion ?? null, estado: b.estado ?? e.estado,
  })
  return { idEquipo: e.idEquipo }
})
