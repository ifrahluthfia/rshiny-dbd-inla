FROM rocker/r-ver:4.3.2

# ---- Dependency sistem untuk sf, spdep, dan R-INLA ----
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    && rm -rf /var/lib/apt/lists/*

# ---- Package R yang dibutuhkan API ----
RUN R -e "install.packages(c('plumber','dplyr','sf','spdep','jsonlite'), repos='https://cloud.r-project.org')"

# ---- Package INLA ----
RUN R -e "install.packages('INLA', repos=c(getOption('repos'), INLA='https://inla.r-inla-download.org/R/stable'))"

WORKDIR /app

# ---- Salin file yang dibutuhkan API saja ----
COPY api.R /app/api.R
COPY shp/ /app/shp/

# Render menentukan PORT lewat environment variable, bukan selalu 8000
ENV PORT=8000
EXPOSE 8000

CMD ["R", "-e", "plumber::plumb('api.R')$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 8000)))"]
