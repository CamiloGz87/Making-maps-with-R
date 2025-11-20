# Making-maps-with-R
Proyectos de visualización de datos geoespaciales y cartografía generados mediante librerías de R

---
title: 'Generación de Mapas Temáticos en R: Ejemplo Aplicado a Prestadores de Servicios
  de Salud en Colombia'
subtitle: "[C. Camilo González](https://www.linkedin.com/in/cristiancamilogonzalezmarinco)"
author: "camilo3144@gmail.com"
date: "`r Sys.Date()`"
output:
  html_document:
    toc: true        # activar índice
    toc_float: true  # que sea flotante (como en la imagen)
    number_sections: true  # opcional: numerar secciones
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(
	echo = TRUE,
	message = FALSE,
	warning = FALSE
)
```

## Introducción

El análisis geográfico en R se ha consolidado como una estrategia robusta para integrar información espacial con datos administrativos, demográficos y epidemiológicos dentro de un mismo flujo analítico reproducible. Su ecosistema —basado en paquetes como `sf`, `terra`, `mapview` y `ggplot2`— permite manipular geometrías, construir visualizaciones temáticas, desarrollar mapas interactivos y vincular directamente estos insumos con modelos estadísticos y técnicas de inferencia espacial.

Desde la perspectiva bioestadística, trabajar en R facilita una trazabilidad completa del proceso: cada transformación, unión espacial, clasificación de valores o ajuste visual queda registrado en código, lo que asegura replicación exacta, auditorías metodológicas y versiones comparables del análisis a lo largo del tiempo. Además, la integración con métodos como autocorrelación espacial, modelos CAR/BYM, suavizamientos empíricos o regresiones geográficamente ponderadas hace que el componente cartográfico no sea un resultado aislado, sino una extensión natural del análisis cuantitativo.

Para ilustrar el flujo, se emplean datos simples a nivel departamental (como número de prestadores habilitados o densidad poblacional), aunque el enfoque es completamente generalizable a cualquier métrica territorial: tasas de eventos, indicadores de acceso, perfiles epidemiológicos, carga de enfermedad, determinantes sociales o métricas operativas del sistema de salud.

El desarrollo propuesto es más simple que otros métodos cartográficos avanzados, pero resulta pragmático, reproducible y adecuado para fines analíticos. Se estructura en tres componentes clave:

1.  generación de mapas interactivos mediante [`mapview`](https://cran.r-project.org/web/packages/mapview/),

2.  comparación visual de variables mediante mapas sincronizados ([`leafsync`](https://cran.r-project.org/web//packages//leafsync/index.html)), y

3.  creación de un mapa estático en calidad de publicación con [`ggplot2`](https://cran.r-project.org/web/packages/ggplot2/index.html). Además, se incorpora un recurso técnico basado en la arquitectura interna de [`leaflet`](https://cran.r-project.org/web/packages/leaflet/index.html) para añadir un minimapa navegacional, útil en análisis nacionales o territorios amplios donde el contexto espacial mejora la interpretación.

Aunque herramientas SIG como [**QGIS**](https://qgis.org/) y [**ArcGIS Pro**](https://www.esri.com/en-us/arcgis/products/arcgis-pro/overview) ofrecen capacidades más avanzadas en edición espacial, modelación geográfica y composición cartográfica, el enfoque en R aporta mayor eficiencia analítica, automatización, reproducibilidad y articulación con procesos estadísticos complejos, lo que lo convierte en una alternativa estratégica en investigación, salud pública, economía de la salud y evaluación territorial.

## Preparación del entorno

La preparación del entorno analítico asegura consistencia, reproducibilidad y control sobre todo el flujo geoespacial. En esta etapa se cargan las librerías fundamentales, se establecen parámetros comunes para estandarizar la ejecución y se definen las fuentes de datos espaciales y administrativas que servirán como base del análisis.

### Carga de librerías

Se utilizan librerías del ecosistema geoespacial de R que permiten manipular objetos espaciales, generar mapas interactivos, sincronizar vistas y producir visualizaciones estáticas de calidad.

```{r}
# Carga de librerías principales
library(sf)            # Manipulación de objetos espaciales en formato simple features
library(dplyr)         # Transformación y manejo de datos
library(mapview)       # Mapas interactivos basados en leaflet
library(leafsync)      # Sincronización de múltiples mapas interactivos
library(classInt)      # Cálculo de cortes (Jenks, cuantiles, etc.)
library(RColorBrewer)  # Paletas de colores
library(rnaturalearth) # Descarga de geometrías oficiales
library(stringi)       # Normalización de nombres
library(leaflet)       # Funciones adicionales para interacción (minimapa)
library(ggplot2)       # Mapas estáticos de alta calidad
library(scales)        # Formatos numéricos (separadores de miles)
library(httr)          # Descargar el archivo desde GitHub
library(readxl)        # Leer el Excel descargado desde GitHub
library(htmlwidgets)   # Guardar e incrustar mapas interactivos en archivos HTML
```

### Fuentes de datos espaciales (Natural Earth) y datos técnicos

El análisis utiliza geometrías oficiales provenientes de [`Natural Earth`](https://cran.r-project.org/web/packages/rnaturalearth/index.html), una fuente estandarizada para divisiones político-administrativas, y un conjunto de datos administrativos suministrado por el usuario para ilustrar el flujo.

#### Geometrías espaciales

```{r}
# Descarga de divisiones administrativas de nivel 1 (departamentos)
col_dept <- ne_states(country = "colombia", returnclass = "sf") |>
  dplyr::select(name, geometry)

# Eliminar polígonos sin nombre (islotes no administrativos que vienen en Natural Earth)
col_dept <- col_dept |>
  dplyr::filter(!is.na(name))
```

Estas geometrías se encuentran en formato simple features (`sf`), lo que permite manipulación eficiente, operaciones espaciales y mezcla con datos tabulares.

#### Datos técnicos

```{r}

url_ips <- "https://raw.githubusercontent.com/CamiloGz87/Making-maps-with-R/main/datos/analisis_geografico_IPS.xlsx"

tmp <- tempfile(fileext = ".xlsx")
GET(url_ips, write_disk(tmp, overwrite = TRUE))

analisis_geografico_IPS <- read_excel(tmp)
```

El conjunto de datos `analisis_geografico_IPS` combina información demográfica y operativa del sistema de salud, asociada al nivel departamental en Colombia, proveniente de dos fuentes oficiales:

-   **Población y densidad poblacional:** datos derivados del [**Censo Nacional de Población y Vivienda 2018**](https://www.dane.gov.co/index.php/estadisticas-por-tema/demografia-y-poblacion/censo-nacional-de-poblacion-y-vivenda-2018) del **DANE**.

-   **Prestadores habilitados:** número total de prestadores registrados en el [**Registro Especial de Prestadores de Servicios de Salud – REPS**](https://www.sispro.gov.co/central-prestadores-de-servicios/Pages/REPS-Registro-especial-de-prestadores-de-servicios-de-salud.aspx.), administrado por el Ministerio de Salud y Protección Social.

La consolidación se realiza mediante el nombre del departamento, lo cual permite su vinculación directa con las geometrías espaciales y facilita la construcción de mapas temáticos reproducibles en R.

::: {style="background-color:#f2f2f2; padding:12px; border-radius:6px; font-size:80%;"}
**Nota para el usuario:** esta base cumple un propósito demostrativo dentro del flujo analítico. Puede reemplazarse por cualquier conjunto de datos departamentales o municipales —indicadores epidemiológicos, registros administrativos, encuestas, tasas o métricas operativas— siempre que incluya un identificador territorial compatible. El código está estructurado para adaptarse a estos escenarios con mínimas modificaciones.
:::

## Preprocesamiento y unión espacial

El preprocesamiento garantiza la compatibilidad entre las geometrías oficiales y las variables administrativas, asegurando que ambos conjuntos puedan integrarse sin inconsistencias. En esta etapa se normalizan los nombres, se inspecciona la estructura espacial, se ejecuta la unión y se valida la integridad del objeto resultante.

### Normalización y homologación de nombres

Para evitar inconsistencias entre fuentes (tildes, diferencias de capitalización, espacios o codificación UTF-8), se genera una clave estandarizada (`depto_norm`) que facilita un emparejamiento seguro entre el shapefile de departamentos y la base administrativa.

```{r}
# Función de normalización
normalizar <- function(x) {
  x |>
    trimws() |>
    toupper() |>
    stri_trans_general("Latin-ASCII")
}

# Normalización en geometrías
col_dept <- col_dept |>
  mutate(depto_norm = normalizar(name))

# Normalización en datos administrativos
analisis_geografico_IPS <- analisis_geografico_IPS |>
  mutate(depto_norm = normalizar(Nombre_Departamento))
```

### Estructura del objeto `sf`

Las geometrías provenientes de `Natural Earth` se encuentran en formato *Simple Features (`sf`)*, que combina atributos tabulares con información geométrica estandarizada. Este formato facilita la integración con el [`tidyverse`](https://cran.r-project.org/web/packages/tidyverse/index.html), operaciones espaciales y visualización.

```{r}
# Inspección inicial del objeto espacial
print(col_dept)
st_geometry_type(col_dept)
st_crs(col_dept)
```

El objeto espacial `col_dept` contiene 33 entidades geográficas correspondientes a los departamentos de Colombia, cada una representada como un multipolígono en formato `sf` y acompañada de atributos limpios que facilitan su integración con datos administrativos. La inspección del tipo de geometría confirma que todas las entidades son `MULTIPOLYGON`, lo que garantiza homogeneidad estructural y evita inconsistencias en operaciones espaciales o procesos de visualización. Adicionalmente, el sistema de referencia espacial asociado es [WGS84 (EPSG:4326)](https://spatialreference.org/ref/epsg/4326/), el estándar global basado en coordenadas geográficas, apropiado para análisis exploratorios, visualizaciones web e interoperabilidad con otras fuentes cartográficas.

### Unión de geometrías con variables de análisis

Una vez normalizados los nombres, se integran las geometrías con los indicadores administrativos mediante un `left_join()` sobre la clave estandarizada `depto_norm`.

```{r}
# Unión espacial (atributos + geometría)
d <- col_dept |>
  left_join(analisis_geografico_IPS, by = "depto_norm")

# Vista preliminar del objeto resultante
d |> dplyr::select(name, depto_norm, Núm_prestadores_habilitados, Densidad_Poblacional) |> head()
```

La unión espacial se realizó correctamente, ya que se evidencia que las geometrías se integraron sin inconsistencias y los indicadores administrativos aparecen asignados de forma coherente, mostrando que el objeto resultante está listo para los mapas y análisis posteriores.

### Validación y diagnóstico de integridad espacial

Después de la unión, se realizan validaciones para asegurar que el objeto espacial resultante es coherente y adecuado para la construcción de mapas. Estas verificaciones permiten asegurar que no existan inconsistencias en los nombres, geometrías corruptas o valores ausentes que puedan afectar la visualización o el análisis espacial posterior.

```{r}
# 1. Verificar departamentos sin emparejar
faltantes <- d |> filter(is.na(Núm_prestadores_habilitados))
faltantes$name

# 2. Comprobar geometrías válidas
sum(!st_is_valid(d))

# 3. Revisar valores faltantes en variables clave
colSums(is.na(d[c("Núm_prestadores_habilitados", "Densidad_Poblacional")]))

# 4. Confirmar el CRS utilizado
st_crs(d)
```

La validación confirma que la unión espacial es completamente consistente: no hay departamentos sin emparejar, todas las geometrías son válidas, las variables clave no tienen valores faltantes y el CRS es WGS84. En conjunto, el objeto espacial está limpio y listo para ser usado en los mapas sin riesgo de errores.

## Generación del mapa base

Una vez asegurada la correcta carga y estructura de las geometrías, se construye un mapa base que servirá como capa de referencia para los mapas temáticos posteriores. Este mapa permite validar visualmente la delimitación departamental y confirmar que la cobertura espacial es coherente con la división político-administrativa del país.

### Selección de atributos geográficos

A partir del objeto espacial completo, se seleccionan únicamente los atributos necesarios para el mapa base: (1) nombre del departamento `name`, (2) clave normalizada `depto_norm` y (3) geometría `geometry`.

```{r}
# Selección de atributos esenciales para el mapa base
col_dept_base <- col_dept |>
  dplyr::select(name, depto_norm, geometry)

col_dept_base
```

#### Visualización preliminar mapa base Colombia

Como primer control visual, se genera un mapa "estático" que permite evaluar rápidamente la cobertura geográfica, la forma de los polígonos y la continuidad de los límites departamentales.

```{r}
# Visualización estática del mapa base

plot(
st_geometry(col_dept_base),
main = "Mapa base de Colombia - Departamentos",
axes = TRUE
)
```

#### Visualización interactiva preliminar mapa base Colombia

La visualización interactiva inicial permite verificar la integridad espacial del objeto `sf` antes de incorporar variables temáticas. Este paso es fundamental para confirmar que:

-   Los límites departamentales se renderizan sin distorsiones,

-   no existen geometrías corruptas (polígonos incompletos o vacíos),

-   el CRS es interpretado correctamente por el motor de visualización,

-   y la estructura espacial es consistente para los procesos posteriores de clasificación, simbología y sincronización de vistas.

A través de `mapview`, se obtiene una representación navegable que facilita la evaluación del mapa base en condiciones reales de exploración.

```{r}
mapview(
  col_dept_base,
  zcol       = "name",
  map.types  = "CartoDB.Positron",
  layer.name = "Departamentos de Colombia"
)
```

## Mapa interactivo en R con `mapview`

En esta sección se construye un mapa temático interactivo a nivel departamental utilizando el número de prestadores habilitados como variable principal. El flujo incluye: definición de variables, cálculo de clases mediante el método de Jenks, configuración de la paleta de colores y generación del mapa interactivo con `mapview`.

### Definición de variables y cortes (Jenks)

Se definen las variables de análisis y una función genérica para calcular los puntos de corte (`breaks`) a partir de la distribución de los datos. En este caso se utiliza el método de [**rupturas naturales de Jenks**](https://pro.arcgis.com/es/pro-app/latest/help/mapping/layer-properties/data-classification-methods.htm), adecuado para resaltar agrupamientos en variables de conteo.

```{r}
# Variables de interés 
var_prest <- "Núm_prestadores_habilitados"
var_dens  <- "Densidad_Poblacional"

# Función para calcular cortes (clases) automáticamente
cortes <- function(variable, k = 7, metodo = "jenks"){
  vals <- variable[!is.na(variable)]
  classInt::classIntervals(vals, n = k, style = metodo)$brks
}

# Filtrar departamentos con dato disponible en la variable de prestadores
d_prest <- d |>
  dplyr::filter(!is.na(.data[[var_prest]]))

# Cortes Jenks para la variable de prestadores
brks_prest <- cortes(d_prest[[var_prest]], k = 7, metodo = "jenks")

brks_prest
```

Los puntos de corte obtenidos muestran una distribución altamente desigual del número de prestadores entre departamentos, con saltos amplios entre clases que evidencian concentración del servicio en pocos territorios. Estas rupturas justifican el uso de Jenks para representar adecuadamente esta variabilidad.

### Configuración de paletas y clases

Se define una paleta de colores secuencial basada en [`RColorBrewer`](https://cran.r-project.org/web/packages/RColorBrewer/index.html) y se ajusta el número de colores al número de clases definido por los cortes de Jenks. Este esquema es apropiado para variables de intensidad o conteo.

```{r}
#Paleta base secuencial
pal_fun <- colorRampPalette(brewer.pal(9, "YlOrRd"))

#Paleta final para el mapa de prestadores
pal_prest <- pal_fun(length(brks_prest) - 1)

pal_prest
```

La paleta **`YlOrRd`** (amarillo–naranja–rojo) permite identificar visualmente los departamentos con mayor concentración relativa de prestadores mediante tonos más intensos. Para explorar más opciones se puede consultar: <https://colorbrewer2.org/>

### Generación del mapa interactivo principal

Con los cortes y la paleta definidos, se construye el mapa temático interactivo. Cada departamento se colorea según el número de prestadores habilitados, estratificado en las clases determinadas por el método de Jenks.

```{r}
map_prest <- mapview(
d_prest,
zcol = var_prest, # variable que define el color del mapa
at = brks_prest, # cortes de clase (Jenks)
col.regions = pal_prest, # paleta aplicada a las clases
map.types = "Esri.WorldTopoMap",
layer.name = "Prestadores habilitados"
)

map_prest
```

El objeto resultante es un mapa interactivo navegable que permite realizar zoom, desplazarse sobre el territorio y consultar los valores asociados a cada departamento mediante interacción directa. El patrón espacial evidencia una alta concentración de prestadores habilitados en Bogotá, Antioquia, Cundinamarca, Santander y Valle del Cauca, conformando el núcleo de mayor oferta en el país. En contraste, departamentos amazónicos y de la Orinoquía presentan baja densidad de prestadores, reflejando brechas estructurales históricas en capacidad instalada y acceso territorial. El gradiente centro–periferia sugiere una asimetría marcada en la distribución de servicios, coherente con la concentración poblacional y el desarrollo de redes asistenciales en las principales aglomeraciones urbanas

#### Consideraciones de interpretación visual

El mapa interactivo cumple un rol principalmente exploratorio y su lectura debe considerar varios aspectos:

-   La variable corresponde a **conteos absolutos** de prestadores por departamento, por lo que está influenciada por el tamaño poblacional y la concentración urbana.

-   La clasificación por **Jenks** optimiza la homogeneidad interna de cada clase, pero no asegura igualdad de frecuencias entre clases ni comparabilidad directa con otros mapas construidos con métodos de clasificación distintos (cuantiles, intervalos iguales, cortes manuales).

-   La simbología secuencial enfatiza las áreas con mayor número relativo de prestadores, pero no incorpora aún información de necesidad poblacional, accesibilidad ni suficiencia de la oferta.

En análisis más especializados *—fuera del alcance de este ejercicio introductorio—* se emplearán indicadores normalizados (por población, área o necesidades esperadas) junto con técnicas espaciales avanzadas como tasas suavizadas, autocorrelación espacial y modelos de riesgo. Estos enfoques permiten interpretaciones más sólidas desde la bioestadística y la planificación en salud.

## Añadir minimapa navegacional con `leaflet` y `mapview`

La incorporación de un minimapa navegacional puede ser útil en visualizaciones interactivas donde la orientación espacial es crítica, especialmente en análisis nacionales o cuando el usuario realiza zoom sobre regiones específicas. Aunque `mapview` no incluye esta funcionalidad de forma nativa, su arquitectura basada en `leaflet` permite extender el mapa accediendo al objeto interno y añadiendo elementos personalizados mediante `addMiniMap()`.

En el contexto del presente ejercicio *—centrado en un análisis descriptivo departamental—* el minimapa **no aporta información adicional ni modifica la interpretación analítica**, dado que los polígonos son amplios, el nivel de zoom no requiere precisión extrema y el objetivo principal es ilustrar la estructura del flujo geoespacial. Aun así, se incluye como ejemplo para mostrar **la flexibilidad del ecosistema R**, así como las posibilidades de ampliación cuando se desarrollan aplicativos interactivos, tableros o herramientas de monitoreo que demandan mayor capacidad de navegación espacial.

### Acceso al objeto `leaflet`

`mapview` encapsula un objeto `leaflet` que puede manipularse aplicando funciones adicionales. Esta propiedad permite añadir elementos como minimapas, capas extra o controles personalizados.

```{r}
# Acceso al mapa leaflet generado por mapview
map_prest_leaflet <- map_prest@map

# Implementación del minimapa con addMiniMap()
map_prest_minimap <- map_prest_leaflet |>
addMiniMap(
toggleDisplay = TRUE, # Permite ocultar/mostrar el minimapa
minimized = FALSE, # Aparece expandido al inicio
position = "bottomright"
)

map_prest_minimap

# Guardar mapa interactivo como HTML
mapview::mapshot(
  map_prest_minimap,
  file = "mapa_prestadores_interactivo.html"
)
```

## Mapas sincronizados para análisis comparativo con `leafsync`

El análisis espacial comparado es una herramienta fundamental cuando se busca evaluar simultáneamente dos indicadores territoriales que pueden presentar relaciones de interés. En este ejercicio se contrastan **el número de prestadores habilitados** y **la densidad poblacional**, permitiendo observar si la distribución de la oferta en salud se alinea o no con el tamaño poblacional departamental.

El uso de `leafsync` facilita esta exploración al permitir que dos mapas interactivos compartan automáticamente la misma vista, zoom y posición, lo cual elimina sesgos derivados de diferencias de escala o encuadre y mejora la precisión visual del análisis exploratorio.

### Justificación del enfoque sincronizado

La sincronización de mapas resulta especialmente útil cuando se comparan indicadores territoriales que presentan escalas, distribuciones o unidades de medida diferentes. Este enfoque permite observar de manera simultánea patrones espaciales, manteniendo un mismo nivel de zoom y un encuadre idéntico en ambas visualizaciones, lo cual evita distorsiones interpretativas y facilita la lectura comparada.

En este ejercicio, la sincronización ayuda a contrastar la distribución de **prestadores habilitados** frente a la **densidad poblacional**, permitiendo identificar visualmente territorios donde la capacidad instalada podría no corresponder con el peso demográfico local.

::: {style="ackground-color:#f2f2f2; padding:12px; border-radius:6px; font-size:80%;"}
**Nota técnica:** la densidad poblacional corresponde al cociente entre la población departamental (DANE 2018) y el área oficial (Natural Earth).\
$$
\text{Densidad} = \frac{\text{Población}}{\text{Área (km}^2\text{)}}
$$ En análisis posteriores se calculará el área con `sf::st_area()` para validar consistencia.
:::

Es importante señalar que este enfoque es **exploratorio** y no sustituye un análisis cuantitativo formal. En un análisis complementario se abordarán **análisis bivariados**, construcción de **indicadores derivados** (p. ej., prestadores por 10.000 habitantes) y la aplicación de **técnicas estadísticas y espaciales más robustas**, entre otros:

-   autocorrelación espacial bivariada,\
-   modelos espaciales compartidos (CAR/BYM),\
-   razones suavizadas mediante métodos empíricos bayesianos,\
-   modelos de regresión geográficamente ponderada (GWR),\
-   análisis de accesibilidad y gravedad,\
-   mapas de discrepancia ajustada por población.

La sincronización de mapas es, por tanto, una primera aproximación visual que orienta hipótesis y facilita la detección preliminar de patrones espaciales relevantes antes de aplicar métodos estadísticos formales.

```{r}
# Cálculo de cortes independientes por variable

# Cortes Jenks para densidad poblacional
brks_dens <- cortes(d[[var_dens]], k = 7, metodo = "jenks")

# Paleta asociada
pal_dens <- pal_fun(length(brks_dens) - 1)

brks_dens

# Construcción de los mapas temáticos independientes
# Mapa 1: Prestadores habilitados
m1 <- mapview(
d,
zcol = var_prest,
at = brks_prest,
col.regions = pal_prest,
map.types = "CartoDB.Positron",
na.color = "transparent",
layer.name = "Prestadores habilitados"
)

# Mapa 2: Densidad poblacional
m2 <- mapview(
d,
zcol = var_dens,
at = brks_dens,
col.regions = pal_dens,
map.types = "CartoDB.Positron",
na.color = "transparent",
layer.name = "Densidad poblacional"
)

# Sincronización de vistas con leafsync
sync_map <- leafsync::sync(m1, m2)
sync_map
```

## Mapa coroplético con `ggplot2`

Los mapas estáticos son esenciales cuando se requiere generar insumos formales para informes técnicos, artículos científicos o presentaciones institucionales. A diferencia de los mapas interactivos, permiten un control total sobre la simbología, la tipografía, la disposición gráfica y la composición general.\
En esta sección se construye un **mapa coroplético estático de prestadores habilitados**, aplicando cortes de Jenks y una paleta secuencial que facilita la interpretación visual.

### Preparación de clases y etiquetas

Se emplea el mismo criterio de clasificación (Jenks) utilizado en el análisis interactivo. Para mejorar la lectura del mapa en un entorno estático, se generan etiquetas formateadas con separadores de miles.

```{r}
# Filtrar departamentos con dato disponible
d_prest_static <- d |>
  dplyr::filter(!is.na(.data[[var_prest]]))

# Cortes Jenks para variable de prestadores
brks_prest_static <- cortes(d_prest_static[[var_prest]], k = 7, metodo = "jenks")

# Etiquetas formateadas para la leyenda
labs_brks   <- scales::comma(brks_prest_static, accuracy = 1)
labs_clases <- paste0(labs_brks[-length(labs_brks)], " – ", labs_brks[-1])

# Crear variable categórica con rangos
d_prest_static <- d_prest_static |>
  mutate(clase_prest = cut(
    .data[[var_prest]],
    breaks = brks_prest_static,
    include.lowest = TRUE,
    labels = labs_clases
  ))
```

### Cálculo de centroides para etiquetas departamentales

Los mapas "estáticos" requieren posicionar manualmente las etiquetas. Para ello se utiliza `st_point_on_surface()`, que garantiza que el punto quede dentro del polígono incluso en geometrías complejas.

```{r}
d_centroid <- d_prest_static |>
mutate(centro = st_point_on_surface(geometry)) |>
mutate(
x = st_coordinates(centro)[,1],
y = st_coordinates(centro)[,2]
)
```

### Generación del mapa con `ggplot2`

El mapa se diseña utilizando una paleta secuencial de `RColorBrewer`, con líneas delgadas para límites departamentales y etiquetado discreto para evitar saturación visual.

```{r}
p_mapa_prest <- ggplot() +
geom_sf(
data  = d_prest_static,
aes(fill = clase_prest),
color = "black", size = 0.2
) +
geom_text(
data = d_centroid,
aes(x = x, y = y, label = name),
size = 2, color = "gray10", check_overlap = TRUE
) +
scale_fill_brewer(
palette = "YlOrRd",
name    = "Prestadores habilitados",
na.translate = FALSE
) +
labs(
title   = "Colombia — Prestadores habilitados por departamento",
caption = "Fuentes: REPS (MSPS) y DANE — CNPV 2018"
) +
theme_void() +
theme(
plot.title   = element_text(hjust = 0.5, face = "bold"),
legend.position = "right",
plot.caption = element_text(size = 8, hjust = 0, color = "gray30")
)

p_mapa_prest
```

### Exportación en alta resolución (300 dpi)

El mapa final se puede exportar en formato PNG con resolución adecuada para informes técnicos y entregables operativos. No obstante, dependiendo del nivel de detalle requerido o del tipo de análisis —por ejemplo, modelación espacial avanzada, edición cartográfica de alta precisión o requisitos editoriales estrictos— pueden considerarse herramientas más robustas como *QGIS*, *ArcGIS Pro* o flujos vectoriales en *PDF/SVG* que ofrecen mayor control sobre simbología, composición y tratamiento del espacio.

```{r}
ggsave(
filename = "mapa_prestadores_hd.png",
plot = p_mapa_prest,
width = 14,
height = 8,
units = "in",
dpi = 300
)
```

::: {style="background-color:#f2f2f2; padding:10px; border-radius:6px; font-size:80%;"}
Este flujo constituye una base replicable para análisis espaciales simples en R, adaptable a distintos indicadores y niveles territoriales.\
Para consultas técnicas o ampliación metodológica:🔗**LinkedIn:** <https://www.linkedin.com/in/camilogz>
:::

