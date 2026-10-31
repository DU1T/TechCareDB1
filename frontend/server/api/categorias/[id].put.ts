import { editarSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de PUT /categorias/{id}
export default defineEventHandler((event) => editarSim(event, 'categorias'))
