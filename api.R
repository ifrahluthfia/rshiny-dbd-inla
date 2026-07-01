# ============================================================
# PLUMBER API — BACKEND INLA
# Menjalankan model Bayesian Spatio-Temporal (R-INLA)
# Dipanggil oleh R Shiny (client) lewat HTTP POST
#
# PENTING: File ini HANYA berisi definisi endpoint plumber.
# JANGAN memanggil plumber::plumb("api.R") atau pr$run() di
# dalam file ini sendiri — itu menyebabkan nested call yang
# bikin container crash saat start (-> muncul sebagai 502 di
# Railway). Yang menjalankan plumb()+run() adalah CMD di
# Dockerfile (lihat instruksi terpisah).
# ============================================================

library(plumber)
library(INLA)
library(dplyr)
library(sf)
library(spdep)
library(jsonlite)

# ----------------------------------------------------------------
# Load shapefile SEKALI saat API start (bukan setiap request)
# ----------------------------------------------------------------
shp_global <- sf::st_read("shp/Sumatera_Utara_ADMIN_BPS.shp", quiet = TRUE)
shp_global <- sf::st_make_valid(shp_global)
kab_col_global <- "Kabupaten"
shp_global[[kab_col_global]] <- trimws(tolower(shp_global[[kab_col_global]]))

# ----------------------------------------------------------------
# Helper: bangun adjacency graph INLA dari shapefile + data
# ----------------------------------------------------------------
build_graph <- function(d) {
  
  d$kabkota <- trimws(tolower(d$kabkota))
  
  shp <- shp_global[shp_global[[kab_col_global]] %in% d$kabkota, ]
  
  cat("MATCH COUNT:", nrow(shp), "\n")
  
  if (nrow(shp) < 2) {
    stop("Kabkota tidak cukup / tidak match dengan shapefile")
  }
  
  nb <- spdep::poly2nb(shp)
  
  if (length(nb) == 0) {
    stop("Adjacency graph kosong")
  }
  
  # Tulis graph ke file temporer lalu baca ulang — cara paling robust
  # untuk semua versi INLA (menghindari error "no method for coercing listw")
  tmp <- tempfile(fileext = ".graph")
  spdep::nb2INLA(tmp, nb)
  g <- INLA::inla.read.graph(tmp)
  
  list(g = g, shp = shp, kab_col = kab_col_global)
}

# ----------------------------------------------------------------
# Helper: siapkan data (rename, idarea, idtime, standarisasi)
# ----------------------------------------------------------------
prepare_data <- function(df, covariates) {
  
  d <- df
  
  if (!"y" %in% names(d) && "Y" %in% names(d)) {
    d <- d %>% rename(y = Y)
  }
  
  if (!"area_idx" %in% names(d)) {
    d$area_idx <- as.integer(factor(d$kabkota))
  }
  if (!"time_idx" %in% names(d)) {
    d$time_idx <- as.integer(factor(d$tahun))
  }
  
  if (!"E" %in% names(d)) {
    pop_col <- grep("(?i)penduduk|population|pop", names(d), value = TRUE)[1]
    if (!is.na(pop_col)) {
      total_rate <- sum(d$y, na.rm = TRUE) / sum(d[[pop_col]], na.rm = TRUE)
      d$E <- d[[pop_col]] * total_rate
    } else {
      d$E <- mean(d$y, na.rm = TRUE)
    }
  }
  
  vars_std <- covariates
  d <- d %>%
    mutate(across(all_of(vars_std), ~ as.numeric(scale(.))))
  
  d$idarea  <- d$area_idx
  d$idarea2 <- d$area_idx
  d$idtime  <- d$time_idx
  
  d
}

# ----------------------------------------------------------------
# Helper: fit model INLA sesuai pilihan spasial & temporal
# ----------------------------------------------------------------
fit_inla_model <- function(d, gr, covariates, spat_model, temp_model) {
  
  cov_formula <- paste(covariates, collapse = " + ")
  
  prior_bym2 <- list(
    prec = list(prior = "pc.prec", param = c(0.5, 0.01)),
    phi  = list(prior = "pc",      param = c(0.5, 0.5))
  )
  
  if (spat_model == "bym") {
    f <- as.formula(
      paste0(
        "y ~ 1 + ", cov_formula,
        " + f(idarea, model='besag', graph=gr) + ",
        "f(idarea2, model='iid') + ",
        "f(idtime, model='", temp_model, "')"
      )
    )
  } else if (spat_model == "bym2") {
    f <- as.formula(
      paste0(
        "y ~ 1 + ", cov_formula,
        " + f(idarea, model='bym2', graph=gr, hyper=prior_bym2) + ",
        "f(idtime, model='", temp_model, "')"
      )
    )
  } else {
    stop(paste0("spatial_model tidak dikenali: '", spat_model,
                "'. Gunakan 'bym' atau 'bym2'."))
  }
  
  if (!temp_model %in% c("rw1", "rw2", "ar1")) {
    stop(paste0("temporal_model tidak dikenali: '", temp_model,
                "'. Gunakan 'rw1', 'rw2', atau 'ar1'."))
  }
  
  # Batasi thread INLA supaya tidak rakus RAM
  INLA::inla.setOption(num.threads = "1:1")
  
  INLA::inla(
    f,
    family = "nbinomial",
    data = d,
    E = d$E,
    control.compute  = list(dic = TRUE, waic = TRUE, cpo = FALSE),
    control.predictor = list(compute = TRUE)
  )
}

# ----------------------------------------------------------------
# Helper: ubah hasil objek INLA menjadi list yang JSON-friendly
# ----------------------------------------------------------------
build_response <- function(res, d, covariates, spat_model) {
  
  fx <- res$summary.fixed
  fx <- fx[rownames(fx) != "(Intercept)", , drop = FALSE]
  fx$variable <- rownames(fx)
  fx$RR     <- exp(fx$mean)
  fx$RR_low <- exp(fx$`0.025quant`)
  fx$RR_up  <- exp(fx$`0.975quant`)
  rownames(fx) <- NULL
  
  prob_inc <- sapply(covariates, function(v) {
    mg <- res$marginals.fixed[[v]]
    round((1 - INLA::inla.pmarginal(0, mg)) * 100, 2)
  })
  prob_dec <- sapply(covariates, function(v) {
    mg <- res$marginals.fixed[[v]]
    round(INLA::inla.pmarginal(0, mg) * 100, 2)
  })
  posterior_probability <- data.frame(
    variable = covariates,
    prob_increase_pct = as.numeric(prob_inc),
    prob_decrease_pct = as.numeric(prob_dec)
  )
  
  summary_random <- lapply(res$summary.random, function(x) x)
  summary_fitted <- res$summary.fitted.values
  
  relative_risk <- data.frame(
    kabkota = d$kabkota,
    tahun   = d$tahun,
    RR      = res$summary.fitted.values[, "mean"] / d$E
  )
  
  list(
    status        = "success",
    spatial_model = spat_model,
    summary_fixed = fx,
    summary_random = summary_random,
    summary_fitted = summary_fitted,
    dic  = res$dic$dic,
    waic = res$waic$waic,
    posterior_probability = posterior_probability,
    relative_risk = relative_risk
  )
}

# ----------------------------------------------------------------
# CORS — supaya bisa dipanggil dari shinyapps.io (domain berbeda)
# ----------------------------------------------------------------
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
    res$setHeader("Access-Control-Allow-Headers", "Content-Type")
    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}

# ----------------------------------------------------------------
# Endpoint: health check
# ----------------------------------------------------------------
#* @get /health
function() {
  list(status = "ok", message = "INLA API is running")
}

# ----------------------------------------------------------------
# Endpoint utama: POST /run
# ----------------------------------------------------------------
#* @post /run
#* @serializer unboxedJSON
function(req, res) {
  
  tryCatch({
    
    body <- jsonlite::fromJSON(req$postBody, simplifyDataFrame = TRUE)
    
    if (is.null(body$data) || length(body$data) == 0) {
      res$status <- 400
      return(list(status = "error", message = "Field 'data' kosong atau tidak ada."))
    }
    if (is.null(body$covariates) || length(body$covariates) == 0) {
      res$status <- 400
      return(list(status = "error", message = "Field 'covariates' kosong atau tidak ada."))
    }
    if (is.null(body$spatial_model)) {
      res$status <- 400
      return(list(status = "error", message = "Field 'spatial_model' tidak ada."))
    }
    if (is.null(body$temporal_model)) {
      res$status <- 400
      return(list(status = "error", message = "Field 'temporal_model' tidak ada."))
    }
    
    df <- as.data.frame(body$data, stringsAsFactors = FALSE)
    covariates <- as.character(body$covariates)
    
    missing_cov <- setdiff(covariates, names(df))
    if (length(missing_cov) > 0) {
      res$status <- 400
      return(list(
        status = "error",
        message = paste("Kovariat tidak ditemukan di data:",
                        paste(missing_cov, collapse = ", "))
      ))
    }
    
    required_cols <- c("kabkota", "tahun")
    missing_req <- setdiff(required_cols, names(df))
    if (length(missing_req) > 0) {
      res$status <- 400
      return(list(
        status = "error",
        message = paste("Kolom wajib tidak ditemukan:",
                        paste(missing_req, collapse = ", "))
      ))
    }
    
    cat(sprintf(
      "[%s] Request diterima | n_baris=%d | covariates=%s | spatial=%s | temporal=%s\n",
      format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      nrow(df),
      paste(covariates, collapse = ","),
      body$spatial_model,
      body$temporal_model
    ))
    
    d  <- prepare_data(df, covariates)
    gr <- build_graph(d)
    
    t0 <- Sys.time()
    res_inla <- fit_inla_model(d, gr$g, covariates, body$spatial_model, body$temporal_model)
    t1 <- Sys.time()
    
    cat(sprintf("[%s] Model selesai dalam %.1f detik\n",
                format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                as.numeric(difftime(t1, t0, units = "secs"))))
    
    out <- build_response(res_inla, d, covariates, body$spatial_model)
    out
    
  }, error = function(e) {
    cat(sprintf("[%s] ERROR: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), conditionMessage(e)))
    res$status <- 500
    list(status = "error", message = conditionMessage(e))
  })
}