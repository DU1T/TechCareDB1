import { ROLES } from '../utils/simuladoUsuarios'
// API SIMULADA de GET /roles
export default defineEventHandler((event) => { requerirSimulado(event); return ROLES })
