import { crearSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de POST /categorias
export default defineEventHandler((event) => crearSim(event, 'categorias'))
