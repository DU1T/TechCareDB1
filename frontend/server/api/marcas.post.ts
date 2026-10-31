import { crearSim } from '../utils/simuladoCatalogos'
// API SIMULADA de POST /marcas
export default defineEventHandler((event) => crearSim(event, 'marcas'))
