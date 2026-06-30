# build-trigger-v4-r2u
FROM rocker/r2u:24.04

ENV DEBIAN_FRONTEND=noninteractive

# r2u menyediakan package R sebagai binary lewat apt, jadi install jauh lebih
# cepat dan tidak perlu compile dari source (menghindari masalah dependency
# seperti s2/sf yang gagal compile manual).
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-plumber \
    r-cran-dplyr \
    r-cran-jsonlite \
    r-cran-httr2 \
    r-cran-dt \
    r-cran-ggplot2 \
    r-cran-tidyr \
    r-cran-car \
    r-cran-sf \
    r-cran-spdep \
    libsodium-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# fmesher tidak selalu tersedia sebagai binary r2u, install dari CRAN source
# (sf sudah ada lewat binary di atas, jadi fmesher tinggal compile ringan)
RUN Rscript -e "install.packages('fmesher', repos='https://cloud.r-project.org')"

RUN Rscript -e "install.packages('INLA', repos=c(INLA='https://inla.r-inla-download.org/R/stable', CRAN='https://cloud.r-project.org'))"

# Verifikasi eksplisit semua package penting bisa di-load.
# Kalau ada yang gagal, build akan STOP di sini dengan pesan error jelas,
# bukan baru ketahuan saat runtime.
RUN Rscript -e "library(plumber); library(INLA); library(sf); library(spdep); cat('OK: semua package terinstall dan dapat di-load\n')"

WORKDIR /app
COPY . .

EXPOSE 10000

CMD ["Rscript", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 10000)))"]