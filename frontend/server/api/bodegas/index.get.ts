import { BODEGAS } from '../../utils/simuladoCatalogos'
// API SIMULADA de GET /bodegas
export default defineEventHandler((event) => { requerirSimulado(event); return BODEGAS })
