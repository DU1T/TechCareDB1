import { USUARIOS } from '../../utils/simuladoUsuarios'
// API SIMULADA de GET /usuarios
export default defineEventHandler((event) => { requerirSimulado(event); return USUARIOS })
