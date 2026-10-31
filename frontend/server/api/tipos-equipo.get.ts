import { TIPOS } from '../utils/simuladoClientes'
// API SIMULADA de GET /tipos-equipo
export default defineEventHandler((event) => { requerirSimulado(event); return TIPOS })
