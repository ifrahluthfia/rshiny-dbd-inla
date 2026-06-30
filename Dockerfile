# build-trigger-v3-ubuntu24
FROM rocker/r-ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System libraries dibutuhkan untuk sf, spdep, dan geospatial stack lainnya
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgdal-dev \
    gdal-bin \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libsodium-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages(c('plumber','dplyr','jsonlite','httr2','DT','ggplot2','tidyr','car','sf','spdep','fmesher'), repos='https://cloud.r-project.org')"

RUN Rscript -e "install.packages('INLA', repos=c(INLA='https://inla.r-inla-download.org/R/stable', CRAN='https://cloud.r-project.org'))"

# Verifikasi eksplisit semua package penting bisa di-load.
# Kalau ada yang gagal, build akan STOP di sini dengan pesan error jelas,
# bukan baru ketahuan saat runtime.
RUN Rscript -e "library(plumber); library(INLA); library(sf); library(spdep); cat('OK: semua package terinstall dan dapat di-load\n')"

WORKDIR /app
COPY . .

EXPOSE 10000

CMD ["Rscript", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 10000)))"]