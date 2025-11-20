# Making-maps-with-R
Proyectos de visualización de datos geoespaciales y cartografía generados mediante librerías de R

Generación de Mapas Temáticos de Colombia en R
Este proyecto contiene un flujo de trabajo en R para la generación, procesamiento y visualización de mapas coropléticos (temáticos) de Colombia. El script se centra en el análisis espacial de indicadores de salud, específicamente la cantidad de prestadores de servicios de salud (IPS) y la densidad poblacional por departamento.

📋 Descripción
El código permite transformar datos estadísticos y geográficos en visualizaciones de alto impacto. Se abordan dos enfoques:

Mapas Estáticos: Diseñados para publicaciones impresas o reportes PDF, con etiquetas de nombres centradas y escalas de color optimizadas.

Mapas Interactivos: Diseñados para exploración web, permitiendo hacer zoom, clic en departamentos para ver detalles y comparación sincronizada de variables.

🚀 Funcionalidades Principales
Descarga Automática de Geometrías: Obtención de límites departamentales de Colombia directamente desde Natural Earth.

Normalización de Texto: Función personalizada para estandarizar nombres de departamentos (eliminación de tildes, espacios y conversión a mayúsculas) para asegurar un cruce de datos perfecto.

Clasificación Estadística: Uso del método de Jenks (rupturas naturales) para la creación de rangos en los mapas interactivos.

Visualización Comparativa: Sincronización de dos mapas (Prestadores vs. Densidad) lado a lado utilizando leafsync.

Etiquetado Inteligente: Cálculo de centroides (st_point_on_surface) para la ubicación óptima de las etiquetas en los mapas estáticos.

🛠️ Requisitos del Sistema
Este proyecto utiliza R. Asegúrate de tener instaladas las siguientes librerías antes de ejecutar el script:

R

install.packages(c("sf", "dplyr", "mapview", "leafsync", "classInt", "RColorBrewer", "rnaturalearth", "stringi"))
Librerías Clave
sf: Manejo de datos espaciales (Simple Features).

mapview & leafsync: Visualización interactiva.

ggplot2 (vía tidyverse): Gráficos estáticos.

rnaturalearth: Fuente de mapas base.

📂 Estructura de Datos
El script requiere dos fuentes de información:

Datos Espaciales: Se descargan automáticamente mediante ne_states(country = "colombia").

Datos Tabulares (analisis_geografico_IPS): Un data frame que debe estar cargado en tu entorno de R y contener al menos:

Nombre_Departamento: Clave para unir con el mapa.

prestadores: Variable numérica (conteo de IPS).

densidad_poblacional: Variable numérica.

usage Uso
Carga tu dataset de indicadores en el entorno con el nombre analisis_geografico_IPS.

Ejecuta el script paso a paso.

Salidas:

Objeto p_mapa_prest: Mapa estático listo para imprimir.

Objeto m_prest: Mapa web interactivo.

Visualización sincronizada de los paneles interactivos.
