FROM rocker/geospatial:4.3.3

ENV DEBIAN_FRONTEND=noninteractive

# Install package R yang dibutuhkan
RUN Rscript -e "install.packages(c( \
  'plumber', \
  'dplyr', \
  'jsonlite', \
  'httr2', \
  'DT', \
  'ggplot2', \
  'tidyr', \
  'car' \
), repos='https://cloud.r-project.org')"

# Install INLA
RUN Rscript -e "install.packages( \
'INLA', \
repos=c(INLA='https://inla.r-inla-download.org/R/stable', \
CRAN='https://cloud.r-project.org'))"

# Verifikasi package
RUN Rscript -e "library(plumber); library(INLA); library(sf); library(spdep)"

WORKDIR /app

COPY . .

EXPOSE 8000

CMD ["Rscript", "run_api.R"]