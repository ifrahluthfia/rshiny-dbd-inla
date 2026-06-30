FROM rocker/geospatial:4.3.3

ENV DEBIAN_FRONTEND=noninteractive

RUN Rscript -e "install.packages(c('plumber','dplyr','jsonlite','httr2','DT','ggplot2','tidyr','car','sf','spdep'), repos='https://cloud.r-project.org')"

RUN Rscript -e "install.packages('INLA', repos=c(INLA='https://inla.r-inla-download.org/R/stable', CRAN='https://cloud.r-project.org'))"

WORKDIR /app

COPY . .

EXPOSE 10000

CMD ["Rscript", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', Sys.getenv('PORT', 10000))))"]