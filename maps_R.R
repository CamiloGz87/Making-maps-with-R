# Paquetes y librerias necesarias
# install.packages("sf") - en caso de que no tenga instalado el paquete que habilita la libreria
library(sf)
library(dplyr)
library(mapview)
library(leafsync)
library(classInt)
library(RColorBrewer)
library(rnaturalearth)
library(stringi)

# 1) Mapa base de Colombia (departamentos)
# Descarga desde Natural Earth las divisiones administrativas de nivel 1 (departamentos)
# y conserva únicamente el nombre del departamento y su geometría en formato sf.
col_dept <- ne_states(country = "colombia", returnclass = "sf") |>
  dplyr::select(name, geometry)

# 2) Normalizar nombres (quita tildes, espacios y unifica en mayúsculas para permitir el cruce)
normalizar <- function(x) {
  x |>
    trimws() |>
    toupper() |>
    stri_trans_general("Latin-ASCII")
}

col_dept <- col_dept |>
  mutate(depto_norm = normalizar(name))

analisis_geografico_IPS <- analisis_geografico_IPS |>
  mutate(depto_norm = normalizar(Nombre_Departamento))

# 3) Unión de geometría + datos
# Combina el mapa de departamentos con tus indicadores usando la clave normalizada
d <- col_dept |>
  left_join(analisis_geografico_IPS, by = "depto_norm")

# Variables a mapear
# Guardan los nombres de las columnas que se usarán en los mapas
var_prest <- "Núm_prestadores_habilitados"
var_dens  <- "Densidad_Poblacional"

# Paleta de colores base
pal_fun <- colorRampPalette(brewer.pal(9, "YlOrRd"))

# Función para calcular cortes (clases) automáticamente
# Limpia NA, calcula clases según Jenks/cuántiles y devuelve los puntos de corte
# Jenks: calcula cortes según rupturas naturales de los datos, resaltando variaciones reales.
# ¿Cuándo NO usar Jenks? 
## Cuando necesitas misma cantidad de departamentos por clase → usa quantile.
## Cuando comparas dos variables en la misma escala exacta → usa cortes manuales.
cortes <- function(variable, k = 7, metodo = "jenks"){
  vals <- variable[!is.na(variable)]
  classInt::classIntervals(vals, n = k, style = metodo)$brks
}

# 4) Mapa individual – Prestadores habilitados

# Filtramos solo departamentos con dato (eliminamos NA de la variable a mapear)
d_prest <- d |>
  dplyr::filter(!is.na(.data[[var_prest]]))

# Cortes Jenks calculados
brks_prest <- cortes(d_prest[[var_prest]], k = 7, metodo = "jenks")
pal_prest  <- pal_fun(length(brks_prest) - 1)

map_prest <- mapview(d_prest,
                     zcol        = var_prest,        # variable que define el color del mapa
                     at          = brks_prest,       # cortes para colorear los valores
                     col.regions = pal_prest,        # paleta aplicada a las clases
                     map.types   = "Esri.WorldTopoMap",
                     layer.name  = "Prestadores habilitados")

map_prest   # Visualización del mapa original


# 4.1 Añadir minimapa usando leaflet (truco mapview → leaflet)
library(leaflet)

map_prest_minimap <- map_prest@map |>
  addMiniMap(
    toggleDisplay = TRUE,      # permite ocultar y mostrar el minimapa
    minimized     = FALSE,     # aparece abierto por defecto
    position      = "bottomright"
  )

map_prest_minimap   # Visualizar mapa con minimapa


# 5) Mapas sincronizados – Prestadores + Densidad poblacional

# Cortes automáticos según la variabilidad de cada variable
brks_dens  <- cortes(d[[var_dens]], k = 7, metodo = "jenks")
pal_dens   <- pal_fun(length(brks_dens) - 1)

# Mapa 1: Prestadores habilitados
m1 <- mapview(d,
              zcol        = var_prest,
              at          = brks_prest,
              col.regions = pal_prest,
              map.types   = "CartoDB.Positron",
              layer.name  = "Prestadores habilitados",
              na.color    = "transparent")

# Mapa 2: Densidad poblacional
m2 <- mapview(d,
              zcol        = var_dens,
              at          = brks_dens,
              col.regions = pal_dens,
              map.types   = "CartoDB.Positron",
              layer.name  = "Densidad poblacional",
              na.color    = "transparent")

# Sincroniza zoom y desplazamiento entre los dos mapas
sync_map <- leafsync::sync(m1, m2)
sync_map # Imprime el mapa en el visor de RStudio


# 6) Mapa coroplético estático de prestadores habilitados
library(ggplot2)
library(sf)
library(scales)   # para formatear números con separador de miles

# Usamos los mismos datos de prestadores
d_prest_static <- d |>
  dplyr::filter(!is.na(.data[[var_prest]]))

# Cortes Jenks
brks_prest_static <- cortes(d_prest_static[[var_prest]], k = 7, metodo = "jenks")

# Labels para los rangos
labs_brks   <- scales::comma(brks_prest_static, accuracy = 1)  # 1,234 en lugar de 1.23e+03
labs_clases <- paste0(labs_brks[-length(labs_brks)], " – ", labs_brks[-1])

# Crear clases usando esos labels
d_prest_static <- d_prest_static |>
  mutate(clase_prest = cut(.data[[var_prest]],
                           breaks = brks_prest_static,
                           include.lowest = TRUE,
                           labels = labs_clases))

# Centroides para ubicar los nombres de los departamentos
d_centroid <- d_prest_static |>
  mutate(centro = st_point_on_surface(geometry)) |>
  mutate(x = st_coordinates(centro)[,1],
         y = st_coordinates(centro)[,2])

# Mapa coroplético con nombres de departamentos
p_mapa_prest <- ggplot() +
  geom_sf(data = d_prest_static,
          aes(fill = clase_prest),
          color = "black", size = 0.2) +
  geom_text(data = d_centroid,
            aes(x = x, y = y, label = name),
            size = 2, color = "gray10", check_overlap = TRUE) +
  scale_fill_brewer(palette = "YlOrRd",
                    name = "Prestadores habilitados",
                    na.translate = FALSE) +
  labs(
    title = "Colombia - Prestadores habilitados por departamento",
    caption = "Fuentes: (1) REPS - Registro Especial de Prestadores de Servicios de Salud; (2) DANE - Censo Nacional de Población y Vivienda 2018"
  ) +
  theme_void() +
  theme(
    plot.title  = element_text(hjust = 0.5, face = "bold"),
    legend.position = "right",
    plot.caption = element_text(size = 8, hjust = 0, color = "gray30")
  )

p_mapa_prest # Imprime el mapa en el visor de RStudio

#Guarda el mapa con alta resolución (300 dpi) adecuado para informes técnicos o publicación
ggsave("mapa_prestadores_hd.png",
       plot   = p_mapa_prest,
       width  = 14, height = 8, units = "in",
       dpi    = 300)

