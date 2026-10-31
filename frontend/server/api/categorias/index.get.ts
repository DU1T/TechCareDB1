import { CATEGORIAS } from '../../utils/simuladoCatalogos'
// API SIMULADA de GET /categorias
export default defineEventHandler((event) => { requerirSimulado(event); return CATEGORIAS })
