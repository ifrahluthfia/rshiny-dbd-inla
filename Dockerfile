FROM rocker/r-ver:4.4.1

# Install Linux dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c( \
'plumber', \
'dplyr', \
'jsonlite', \
'sf', \
'spdep' \
), repos='https://cloud.r-project.org')"

# Install INLA
RUN R -e "install.packages('INLA', repos=c(getOption('repos'), INLA='https://inla.r-inla-download.org/R/stable'))"

WORKDIR /app

COPY . .

EXPOSE 8000

CMD ["Rscript","run_api.R"]