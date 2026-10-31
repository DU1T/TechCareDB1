import { CATEGORIAS, REPUESTOS } from '../../utils/simuladoCatalogos'
// API SIMULADA de GET /repuestos (con el nombre de la categoría, como la API real)
export default defineEventHandler((event) => {
  requerirSimulado(event)
  return REPUESTOS.map((r) => ({ ...r, categoria: CATEGORIAS.find((c) => c.idCategoria === r.idCategoria)?.nombre }))
})
