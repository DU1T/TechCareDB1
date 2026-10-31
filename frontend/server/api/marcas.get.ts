import { MARCAS } from '../utils/simuladoClientes'
// API SIMULADA de GET /marcas
export default defineEventHandler((event) => { requerirSimulado(event); return MARCAS })
