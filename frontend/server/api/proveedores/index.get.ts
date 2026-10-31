import { PROVEEDORES } from '../../utils/simuladoCatalogos'
// API SIMULADA de GET /proveedores
export default defineEventHandler((event) => { requerirSimulado(event); return PROVEEDORES })
