import { editarSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de PUT /marcas/{id}
export default defineEventHandler((event) => editarSim(event, 'marcas'))
