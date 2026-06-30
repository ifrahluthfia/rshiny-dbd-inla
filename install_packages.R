# ============================================================
# install_packages.R
# Jalankan SEKALI saja untuk instal semua dependency.
#
# CATATAN: package INLA HANYA perlu diinstal di server API
# (tempat menjalankan api.R). TIDAK perlu diinstal di
# lingkungan yang akan dipakai untuk deploy ke shinyapps.io.
# ============================================================

# ---- Package untuk SHINY CLIENT (app.R) ----
client_packages <- c(
  "shiny", "shinythemes", "dplyr", "ggplot2", "DT",
  "readxl", "tidyr", "sf", "spdep", "car",
  "httr2", "jsonlite"
)

install.packages(setdiff(client_packages, rownames(installed.packages())))

# ---- Package tambahan untuk API SERVER (api.R) ----
# JANGAN dijalankan di lingkungan yang akan dipakai deploy ke shinyapps.io
api_only_packages <- c("plumber")

install.packages(setdiff(api_only_packages, rownames(installed.packages())))

# ---- Package INLA (HANYA untuk server API, BUKAN untuk shinyapps.io) ----
# Jalankan baris ini HANYA di komputer/VPS yang menjalankan api.R
if (!requireNamespace("INLA", quietly = TRUE)) {
  install.packages(
    "INLA",
    repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable")
  )
}
