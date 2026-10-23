// Los roles llegan de la API como códigos (CAJA, TECNICO...). Aquí se muestran con su nombre normal.
const NOMBRES: Record<string, string> = {
  RECEPCION: 'Recepción',
  TECNICO: 'Técnico',
  BODEGA: 'Bodega',
  CAJA: 'Caja',
  ADMINISTRADOR: 'Administrador',
}

export const nombreRol = (codigo: string) => NOMBRES[codigo] ?? codigo
