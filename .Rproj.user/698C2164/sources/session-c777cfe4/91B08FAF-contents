# ============================================================
# SHINY APP — ANALISIS SPASIAL-TEMPORAL RISIKO DBD
# Provinsi Sumatera Utara, 2015–2024
# Model: BYM Klasik / BYM2 + Temporal (RW1 / RW2 / AR1)
#
# VERSI CLIENT: Tidak lagi memanggil INLA::inla() langsung.
# Komputasi model dilakukan oleh API plumber terpisah (api.R),
# dipanggil lewat HTTP. Ini membuat app ini bisa di-deploy ke
# shinyapps.io tanpa perlu menginstall package INLA di sana.
# ============================================================

Sys.setenv(TZ = "UTC")

library(shiny)
library(shinythemes)
library(dplyr)
library(ggplot2)
library(DT)
library(readxl)
library(tidyr)
library(sf)
library(spdep)
library(car)
library(httr2)
library(jsonlite)

# CATATAN: library(INLA) TIDAK lagi di-load di sini.
# Semua fungsi INLA::inla() sudah dipindah ke api.R (backend terpisah).

# ----------------------------------------------------------------
# URL API — UBAH INI sesuai lokasi API Anda
# Lokal   : "http://127.0.0.1:8000"
# Online  : "https://nama-app-anda.onrender.com" (atau VPS/Railway Anda)
# ----------------------------------------------------------------
API_URL <- "https://rshiny-dbd-inla-production.up.railway.app"

# ============================================================
# UI  — TIDAK DIUBAH SAMA SEKALI dari versi asli Anda
# ============================================================

title_tag <- tags$div(

  tags$img(
    src="https://images.seeklogo.com/logo-png/43/1/brin-badan-riset-dan-inovasi-nasional-logo-png_seeklogo-432454.png",
    height="60",
    width="60",
    style="margin-right:10px;"
  ),

  tags$img(
    src = "logo-unhan-removebg-preview-1.jpg",
    height = "60"
  ),

  "Analisis Spasial-Temporal Epidemiologi di Sumatera Utara"
)

ui <- fluidPage(
  theme = shinytheme("superhero"),

tags$style(HTML("
    body { background-color: #5E1914 !important;
      }
    .dataTables_length select {
      color: white !important;
      background-color: #2b3e50 !important;
      border: 1px solid #4e5d6c;
    }

    .dataTables_wrapper{
     color:white !important;
    }

    .dataTables_length option {
      color: black !important;
      background-color: white !important;
    }

    .checkbox-grid {
      column-count: 4;
      column-gap: 20px;
    }

    .checkbox-grid .checkbox {
      display: block;
      margin-top: 5px;
    }

    .checkbox-grid label.control-label{
  font-size: 18px;
  font-weight: bold;
  margin-bottom: 15px;
}

.checkbox-grid .shiny-options-group{
  margin-top: 15px;
}
    ")),
  headerPanel(
    "Analisis Spasial-Temporal Risiko DBD — Provinsi Sumatera Utara 2015–2024",
    title = title_tag
  ),

  sidebarLayout(
    # ---- SIDEBAR ----
    sidebarPanel(
      width = 3,

      tags$h5("1. Upload Data (Excel)"),
      fileInput("file_data", "Data Y & X (.xlsx)", accept = ".xlsx"),


      tags$hr(),

      tags$h5("3. Pilih Model"),
      selectInput("spat_model", "Komponen Spasial",
                  choices = c("BYM1 " = "bym",
                              "BYM2"                     = "bym2"),
                  selected = "bym"),

      selectInput("temp_model", "Komponen Temporal",
                  choices = c("RW1" = "rw1",
                              "RW2" = "rw2",
                              "AR(1)" = "ar1"),
                  selected = "ar1"),

      tags$hr(),

      actionButton("run_model", "▶  Jalankan Model",
                   class = "btn-success btn-block"),

      helpText(
        "Jalankan model setelah memilih variabel."
      ),

      tags$hr(),
      DT::DTOutput("tbl_preview")
    ),

    # ---- MAIN PANEL ----
    mainPanel(
      width = 9,
      tabsetPanel(
        type = "pills",

        # ---------- About ----------
        tabPanel("About", tags$hr(), htmlOutput("about_text")),

        # ---------- Deskripsi Data ----------
        tabPanel(
          "Deskripsi Data",
          tags$hr(),
          tabsetPanel(
            type = "tabs",
            tabPanel("Data", tags$hr(),
                     DT::DTOutput("dt_data")),
            tabPanel("Pemilihan Variabel",br(),uiOutput("pilih_variabel"),br(),
                     verbatimTextOutput("var_terpilih")),
            tabPanel("Statistika Deskriptif", tags$hr(),
                     verbatimTextOutput("deskriptif_print"),
                     tags$hr(),
                     DT::DTOutput("deskriptif_tabel")),
            tabPanel("Boxplot Kovariat", tags$hr(),
                     plotOutput("boxplot_kovariat", height = "500px")),
            tabPanel("Tren Kasus Tahunan", tags$hr(),
                     plotOutput("plot_tren", height = "350px")),
            tabPanel("Peta Hotspot", tags$hr(),
                     plotOutput("peta_hotspot", height = "500px"))
          )
        ),

        # ---------- Pra-Model ----------
        tabPanel(
          "Pra-Model",
          tags$hr(),
          tabsetPanel(
            type = "tabs",
            tabPanel("Uji VIF (Multikolinearitas)", tags$hr(),
                     verbatimTextOutput("vif_out")),
            tabPanel("Matriks Korelasi", tags$hr(),
                     verbatimTextOutput("cor_out"))
          )
        ),

        # ---------- Analisis Kovariat ----------
        tabPanel(
          "Analisis Kovariat",
          tags$hr(),
          tabsetPanel(
            type = "tabs",
            tabPanel("Relative Risk", tags$hr(),
                     DT::DTOutput("tbl_fixed")),
            tabPanel("Posterior Probability", tags$hr(),
                     DT::DTOutput("tbl_prob"))
          )
        ),

        # ---------- Interpretasi Spasial ----------
        tabPanel(
          "Spasial",
          tags$hr(),
          tabsetPanel(
            type = "tabs",
            tabPanel("Tabel Efek Spasial", tags$hr(),
                     DT::DTOutput("tbl_spasial")),
            tabPanel("Peta RR Spasial", tags$hr(),
                     plotOutput("peta_rr_spasial", height = "500px")),
            tabPanel("Exceedance Probability", tags$hr(),
                     plotOutput("peta_exceed", height = "500px"))
          )
        ),

        # ---------- Interpretasi Temporal ----------
        tabPanel(
          "Temporal",
          tags$hr(),
          tabsetPanel(
            type = "tabs",
            tabPanel("Tabel Efek Temporal", tags$hr(),
                     DT::DTOutput("tbl_temporal")),
            tabPanel("Plot Tren Temporal", tags$hr(),
                     plotOutput("plot_temporal", height = "400px")),
            tabPanel("Peta RR per Tahun", tags$hr(),
                     plotOutput("peta_rr_tahun", height = "600px")),
            tabPanel("Peta Posterior Probability",tags$hr(),
                     plotOutput("peta_prob_tahun", height = "600px"))
          )
        ),

        # ---------- Created By ----------
        tabPanel("Created By", tags$hr(), htmlOutput("creator_text"))
      )
    )
  )
)

# ============================================================
# SERVER
# ============================================================

server <- function(input, output, session) {

  # ---- Reaktif: Load Data ----
  data_raw <- reactive({
    req(input$file_data)

    readxl::read_excel(
      input$file_data$datapath
    )
  })

  # ---- Reaktif: Load Shapefile ----
  # Tetap dimuat di sisi Shiny karena dipakai untuk PETA (plot),
  # bukan untuk komputasi INLA (itu dilakukan di API).
  shp_loaded <- reactive({

    shp <- sf::st_read(
      "shp/Sumatera_Utara_ADMIN_BPS.shp",
      quiet = TRUE
    )

    shp <- sf::st_make_valid(shp)

    shp
  })

  # ---- Reaktif: Data Siap (rename + standarisasi + idarea/idtime) ----
  # Logika ini tetap dijalankan di Shiny untuk keperluan PLOT/DESKRIPSI
  # (boxplot, korelasi, VIF, peta hotspot). Data MENTAH (sebelum standarisasi
  # dummy idarea/idtime di sisi server) tetap dikirim utuh ke API; API yang
  # akan menstandarisasi ulang dan membangun idarea/idtime untuk model.
  data_ready <- reactive({
    req(data_raw())
    d <- data_raw()
    d <- d %>%
      rename(y = Y)

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

    excluded <- c(
      "kabkota", "tahun", "y", "E", "area_idx", "time_idx",
      "idarea", "idarea2", "idtime"
    )

    vars_std <- setdiff(names(d), excluded)
    d <- d %>%
      mutate(across(all_of(vars_std), ~ as.numeric(scale(.))))

    d$idarea  <- d$area_idx
    d$idarea2 <- d$area_idx
    d$idtime  <- d$time_idx

    d
  })

  # ---- Variabel yang dipilih user ----
  selected_vars <- reactive({

    req(input$covariates)

    print(input$covariates)
    print(class(input$covariates))
    
    shiny::validate(
      shiny::need(
        length(input$covariates) > 0,
        "Pilih minimal satu kovariat"
      )
    )

    input$covariates
  })

  observeEvent(input$pilih_semua, {

    excluded <- c(
      "kabkota","tahun","y","E","area_idx","time_idx",
      "idarea","idarea2","idtime","area_idx2"
    )

    variabel <- setdiff(
      names(data_ready()),
      excluded
    )

    updateCheckboxGroupInput(
      session,
      "covariates",
      selected = variabel
    )
  })

  observeEvent(input$hapus_semua, {

    updateCheckboxGroupInput(
      session,
      "covariates",
      selected = character(0)
    )
  })

  # ---- Reaktif: Adjacency Graph ----
  # Tetap dipertahankan di sisi Shiny HANYA untuk kebutuhan PLOT PETA
  # (merge shapefile dengan hasil model). Graph INLA untuk model dibangun
  # ulang di sisi API.
  graph_inla <- reactive({
    req(shp_loaded(), data_ready())
    shp  <- shp_loaded()
    d    <- data_ready()

    kab_col <- "Kabupaten"
    shp <- shp[shp[[kab_col]] %in% d$kabkota, ]

    nb <- spdep::poly2nb(shp)

    g <- INLA_graph_dummy <- NULL  # graph INLA tidak dibutuhkan di client lagi
    list(g = g, shp = shp, kab_col = kab_col)
  })

  # ============================================================
  # >>> BAGIAN UTAMA YANG DIUBAH: PEMANGGILAN MODEL VIA HTTP <<<
  # ============================================================

  # ---- Reaktif: Jalankan Model lewat API (menggantikan INLA::inla()) ----
  all_models <- eventReactive(input$run_model, {
    req(data_raw(), selected_vars())

    withProgress(message = "Mengirim data ke API & menjalankan model INLA...", value = 0, {

      incProgress(0.1, detail = "Menyiapkan payload JSON...")

      df_send <- data_raw() %>%
        rename(y = Y)

      body_list <- list(
        data           = df_send,
        covariates     = selected_vars(),
        spatial_model  = input$spat_model,
        temporal_model = input$temp_model
      )

      incProgress(0.2, detail = "Mengirim request ke API...")

      # ---- HTTP POST ke API plumber, dengan timeout & error handling ----
      resp <- tryCatch({
        httr2::request(API_URL) |>
          httr2::req_url_path_append("run") |>
          httr2::req_method("POST") |>
          httr2::req_body_json(body_list, auto_unbox = TRUE) |>
          httr2::req_timeout(600) |>  # 10 menit, model INLA bisa lama
          httr2::req_perform()
      }, error = function(e) {
        showNotification(
          paste("Gagal menghubungi API:", conditionMessage(e)),
          type = "error", duration = NULL
        )
        NULL
      })

      if (is.null(resp)) {
        return(NULL)
      }

      incProgress(0.7, detail = "Memproses respons...")

      # ---- Cek status HTTP ----
      if (httr2::resp_status(resp) != 200) {
        err_body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
        msg <- if (!is.null(err_body$message)) err_body$message else "Error tidak diketahui dari API."
        showNotification(paste("API Error:", msg), type = "error", duration = NULL)
        return(NULL)
      }

      # ---- Simpan response sebagai _live_data_ ----
      `_live_data_` <- resp |> httr2::resp_body_json(simplifyVector = TRUE)

      str(`_live_data_`)
      
      if (!is.null(`_live_data_`$status) && `_live_data_`$status != "success") {
        showNotification(
          paste("Model gagal:", `_live_data_`$message),
          type = "error", duration = NULL
        )
        return(NULL)
      }

      incProgress(0.9, detail = "Selesai.")

      list(
        selected = `_live_data_`,
        label    = paste(
          ifelse(input$spat_model == "bym", "BYM1", "BYM2"),
          "+",
          toupper(input$temp_model)
        )
      )
    })
  })

  # Helper: hasil model dari API (menggantikan res() yang dulu objek INLA)
  res <- reactive({
    req(all_models())
    all_models()$selected
  })

  # ============================================================
  # OUTPUTS — About & Creator (TIDAK DIUBAH)
  # ============================================================

  output$about_text <- renderText({
    HTML(paste(
      "<p>Aplikasi ini mengimplementasikan model <b>Bayesian Spatial-temporal</b>
       menggunakan kerangka INLA (<i>Integrated Nested Laplace Approximation</i>)
       untuk menganalisis risiko penyakit di Provinsi Sumatera Utara, Indonesia.</p>",
      "<p><b>Komponen Spasial:</b> BYM1 atau BYM2<br>
       <b>Komponen Temporal:</b> RW1, RW2, atau AR(1)<br>
       <b>Likelihood:</b> Negative Binomial<br>
        <p>Model terbaik dipilih berdasarkan DIC dan WAIC terkecil.</p>",
      sep = ""
    ))
  })

  output$creator_text <- renderText({
    HTML(paste(
      "Nama Lengkap : Ifrah Luthfia<br>",
      "Universitas Pertahanan Republik Indonesia<br>",
      "Email : ifrahluthfia05@gmail.com<br>",
      sep = "<br>"
    ))
  })

  # ============================================================
  # OUTPUTS — Deskripsi Data (TIDAK DIUBAH)
  # ============================================================

  output$tbl_preview <- DT::renderDT({
    req(data_raw())
    DT::datatable(head(data_raw(), 5),
                  options = list(scrollX = TRUE, dom = "t"),
                  rownames = FALSE)
  })

  output$dt_data <- DT::renderDT({
    req(data_raw())
    DT::datatable(data_raw(),
                  options = list(scrollX = TRUE, pageLength = 15),
                  rownames = FALSE)
  })

  output$pilih_variabel <- renderUI({

    req(data_ready())

    excluded <- c(
      "kabkota","tahun","y","E","area_idx","time_idx",
      "idarea","idarea2","idtime","area_idx2"
    )

    variabel <- setdiff(
      names(data_ready()),
      excluded
    )

    tagList(

      fluidRow(
        column(
          6,
          actionButton(
            "pilih_semua",
            "✓ Pilih Semua",
            class = "btn-success"
          )
        ),
        column(
          6,
          actionButton(
            "hapus_semua",
            "✗ Hapus Semua",
            class = "btn-danger"
          )
        )
      ),

      br(),

      div(
        class = "checkbox-grid",

        checkboxGroupInput(
          "covariates",
          "Pilih Variabel Kovariat",
          choices = variabel,
          selected = variabel
        )
      )
    )
  })

  output$var_terpilih <- renderPrint({
    req(input$covariates)
    input$covariates

  })

  output$deskriptif_print <- renderPrint({
    req(data_ready(), input$covariates)
    summary(
      data_ready()[, input$covariates, drop = FALSE]
    )

  })

  output$deskriptif_tabel <- DT::renderDT({

    req(data_ready(), input$covariates)

    d <- data_ready()

    tbl <- d %>%
      dplyr::select(all_of(input$covariates)) %>%
      tidyr::pivot_longer(
        everything(),
        names_to = "Variabel",
        values_to = "Nilai"
      ) %>%
      dplyr::group_by(Variabel) %>%
      dplyr::summarise(
        Mean   = round(mean(Nilai, na.rm = TRUE), 3),
        SD     = round(sd(Nilai, na.rm = TRUE), 3),
        Min    = round(min(Nilai, na.rm = TRUE), 3),
        Q1     = round(quantile(Nilai, 0.25, na.rm = TRUE), 3),
        Median = round(median(Nilai, na.rm = TRUE), 3),
        Q3     = round(quantile(Nilai, 0.75, na.rm = TRUE), 3),
        Max    = round(max(Nilai, na.rm = TRUE), 3),
        .groups = "drop"
      )

    DT::datatable(
      tbl,
      rownames = FALSE,
      options = list(scrollX = TRUE)
    )

  })

  output$boxplot_kovariat <- renderPlot({

    req(data_ready(), input$covariates)

    d <- data_ready()

    data_long <- d %>%
      select(
        tahun,
        all_of(input$covariates)
      ) %>%
      pivot_longer(
        all_of(input$covariates),
        names_to = "variabel",
        values_to = "nilai"
      )

    ggplot(
      data_long,
      aes(x = factor(tahun), y = nilai)
    ) +
      geom_boxplot(
        fill = "white",
        colour = "black"
      ) +
      facet_wrap(
        ~ variabel,
        scales = "free_y",
        ncol = 4
      ) +
      labs(
        x = "Year",
        y = "Value",
        title = "Distribution of Covariates by Year"
      ) +
      theme_bw() +
      theme(
        plot.title = element_text(
          hjust = 0.5,
          face = "bold"
        ),
        axis.text.x = element_text(
          angle = 45,
          hjust = 1,
          size = 8
        ),
        strip.text = element_text(
          face = "bold"
        )
      )

  })

  output$plot_tren <- renderPlot({
    req(data_ready())
    dbd_tahunan <- aggregate(y ~ tahun, data = data_ready(), FUN = sum, na.rm = TRUE)
    ggplot(dbd_tahunan, aes(x = tahun, y = y)) +
      geom_line(color = "red", linewidth = 1) +
      geom_point(size = 2) +
      geom_text(aes(label = y), vjust = -0.6, size = 3) +
      scale_x_continuous(breaks = min(dbd_tahunan$tahun):max(dbd_tahunan$tahun)) +
      labs(title = "Tren Temporal",
           x = "Year", y = "Total Cases") +
      theme_bw()
  })

  output$peta_hotspot <- renderPlot({
    req(data_ready(), graph_inla())
    d   <- data_ready()
    gr  <- graph_inla()
    shp <- gr$shp
    kc  <- gr$kab_col

    dbd_sp <- aggregate(y ~ kabkota, data = d, FUN = sum, na.rm = TRUE)
    peta <- dplyr::left_join(shp,dbd_sp,by = setNames("kabkota", kc)
    )

    ggplot(sf::st_as_sf(peta)) +
      geom_sf(aes(fill = y), color = "black", size = 0.2) +
      scale_fill_gradient(low = "#FAFAD2", high = "#8B0000",
                          name = "") +
      labs(
        title = "Peta Hotspot"
      ) +
      theme_bw() +
      theme(axis.text = element_blank(), axis.ticks = element_blank(),
            axis.title = element_blank(), panel.grid = element_blank()) +
      coord_sf(datum = NA)
  })

  # ============================================================
  # OUTPUTS — Pra-Model (TIDAK DIUBAH)
  # ============================================================

  output$vif_out <- renderPrint({
    req(data_ready())
    d  <- data_ready()
    f_vif <- as.formula(
      paste(
        "y ~",
        paste(input$covariates, collapse = " + ")
      )
    )

    lm_fit <- lm(f_vif, data = d)
    vif_v  <- car::vif(lm_fit)
    tbl <- data.frame(
      Variabel = names(vif_v),
      VIF = round(vif_v,3),
      Status = ifelse(
        vif_v > 10,
        "MASALAH",
        ifelse(vif_v > 5,"Perhatian","Aman")
      )
    )
    print(tbl)
  })

  output$cor_out <- renderPrint({
    req(data_ready(),
      input$covariates
      )
    vars <- input$covariates
    round(cor(data_ready()[, vars, drop = FALSE],use = "complete.obs"),3)

  })

  # ============================================================
  # OUTPUTS — Fitting Model
  # >>> DIUBAH: semua membaca dari res() (= _live_data_ dari API) <<<
  # ============================================================

  output$tbl_comparison <- DT::renderDT({
    req(all_models())
    m <- all_models()$selected
    lbl <- all_models()$label
    tbl <- data.frame(
      Model = lbl,
      DIC   = round(m$dic,   2),
      WAIC  = round(m$waic, 2)
    )
    DT::datatable(tbl, rownames = FALSE,
                  options = list(dom = "t", scrollX = TRUE))
  })

  output$tbl_fixed <- DT::renderDT({
    req(res())
    fx <- as.data.frame(res()$summary_fixed)
    print(names(fx))
    fx$Credible <- ifelse(fx$RR_low > 1, "+ (meningkatkan risiko)",
                          ifelse(fx$RR_up < 1, "- (menurunkan risiko)",
                                 "tidak signifikan"))
    tbl <- fx[, c("variable","mean","sd","0.025quant","0.975quant","RR","RR_low","RR_up","Credible")]

    tbl[ ,2:8] <- round(tbl[ ,2:8], 4)
    DT::datatable(tbl, rownames = FALSE, options = list(scrollX = TRUE))
  })

  output$tbl_prob <- DT::renderDT({
    req(res())
    pp <- as.data.frame(res()$posterior_probability)
    label <- gsub("_", " ", pp$variable)
    tbl <- data.frame(
      Variabel                   = label,
      `P(meningkatkan DBD) (%)` = pp$prob_increase_pct,
      `P(menurunkan DBD) (%)`   = pp$prob_decrease_pct,
      check.names = FALSE
    )
    DT::datatable(tbl, rownames = FALSE,
                  options = list(scrollX = TRUE, dom = "t"))
  })

  # ============================================================
  # OUTPUTS — Spasial
  # >>> DIUBAH: data spasial dibaca dari res()$summary_random <<<
  # ============================================================

  spasial_df_r <- reactive({
    req(res(), data_ready())
    d <- data_ready()

    rnd <- res()$summary_random

    if (input$spat_model == "bym") {
      st <- as.data.frame(rnd$idarea)
      su <- as.data.frame(rnd$idarea2)
      sp_mean <- st$mean + su$mean
      sp_sd   <- sqrt(st$sd^2 + su$sd^2)
      low_95  <- exp(st[["0.025quant"]] + su[["0.025quant"]])
      up_95   <- exp(st[["0.975quant"]] + su[["0.975quant"]])
    } else {
      st <- as.data.frame(rnd$idarea)
      n  <- nrow(d %>% distinct(area_idx))
      sp_mean <- st$mean[1:n]
      sp_sd   <- st$sd[1:n]
      low_95  <- exp(st[["0.025quant"]][1:n])
      up_95   <- exp(st[["0.975quant"]][1:n])
    }

    kab_list <- d %>% arrange(area_idx) %>% distinct(area_idx, kabkota) %>% pull(kabkota)

    cat("kab_list =", length(kab_list), "\n")
    cat("sp_mean  =", length(sp_mean), "\n")
    cat("sp_sd    =", length(sp_sd), "\n")
    cat("low_95   =", length(low_95), "\n")
    cat("up_95    =", length(up_95), "\n")
    
    data.frame(
      Kabupaten = kab_list,
      Efek_mean = round(sp_mean, 4),
      Exp_Efek  = round(exp(sp_mean), 4),
      Low_95    = round(low_95, 4),
      Up_95     = round(up_95, 4),
      Prob_ui_gt1 = round(1 - pnorm(0, mean = sp_mean, sd = sp_sd), 4)
    )
  })

  output$tbl_spasial <- DT::renderDT({
    req(spasial_df_r())
    tbl <- spasial_df_r() %>% arrange(desc(Exp_Efek))
    DT::datatable(tbl, rownames = FALSE,
                  options = list(scrollX = TRUE, pageLength = 15))
  })

  output$peta_rr_spasial <- renderPlot({
    req(spasial_df_r(), graph_inla())
    gr  <- graph_inla()
    shp <- gr$shp
    kc  <- gr$kab_col

    peta <- merge(shp, spasial_df_r(), by.x = kc, by.y = "Kabupaten", all.x = TRUE)

    ggplot(sf::st_as_sf(peta)) +
      geom_sf(aes(fill = Exp_Efek), color = "black", size = 0.2) +
      scale_fill_gradient2(midpoint = 1,
                           low = "#FAFAD2", high = "#8B0000", name = "") +
      labs(title = "Relative Risk Spasial") +
      theme_bw() +
      theme(axis.text = element_blank(), axis.ticks = element_blank(),
            panel.grid = element_blank())
  })

  output$peta_exceed <- renderPlot({
    req(spasial_df_r(), graph_inla())
    gr  <- graph_inla()
    shp <- gr$shp
    kc  <- gr$kab_col

    peta <- merge(shp, spasial_df_r(), by.x = kc, by.y = "Kabupaten", all.x = TRUE)

    ggplot(sf::st_as_sf(peta)) +
      geom_sf(aes(fill = Prob_ui_gt1), color = "black", size = 0.2) +
      scale_fill_gradient(low = "#FFFFBF", high = "#2C7BB6",
                          limits = c(0, 1), name = "") +
      labs(title = "Exceedance Probability") +
      theme_bw() +
      theme(axis.text = element_blank(), axis.ticks = element_blank(),
            panel.grid = element_blank())
  })

  # ============================================================
  # OUTPUTS — Temporal
  # >>> DIUBAH: data temporal dibaca dari res()$summary_random$idtime <<<
  # ============================================================

  temporal_df_r <- reactive({
    req(res())
    te <- as.data.frame(res()$summary_random$idtime)
    data.frame(
      Tahun    = 2014 + te$ID,
      Efek     = round(te$mean, 4),
      Exp_Efek = round(exp(te$mean), 4),
      Low_95   = round(exp(te[["0.025quant"]]), 4),
      Up_95    = round(exp(te[["0.975quant"]]), 4)
    )
  })

  output$tbl_temporal <- DT::renderDT({
    req(temporal_df_r())
    DT::datatable(temporal_df_r(), rownames = FALSE,
                  options = list(dom = "t", scrollX = TRUE))
  })

  output$plot_temporal <- renderPlot({
    req(temporal_df_r())
    te <- temporal_df_r()
    ggplot(te, aes(x = Tahun)) +
      geom_ribbon(aes(ymin = Low_95, ymax = Up_95),
                  fill = "lightblue", alpha = 0.4) +
      geom_line(aes(y = Exp_Efek), color = "darkred", linewidth = 1) +
      geom_point(aes(y = Exp_Efek), color = "darkred", size = 2.5) +
      geom_hline(yintercept = 1, linetype = "dashed", color = "gray40") +
      scale_x_continuous(breaks = te$Tahun) +
      labs(x = "Year", y = "Temporal Effect)",
           title = paste("Tren Temporal RR"),
           caption = "Dashed line = baseline (RR = 1) | Bluw Shaded = 95% Credible Interval") +
      theme_bw() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })

  output$peta_rr_tahun <- renderPlot({
    req(res(), data_ready(), graph_inla())
    d   <- data_ready()
    gr  <- graph_inla()
    shp <- gr$shp
    kc  <- gr$kab_col

    fitted_mean <- as.data.frame(res()$summary_fitted)$mean
    d$RR <- fitted_mean / d$E

    peta <- merge(shp, d[, c("kabkota","tahun","RR")],
                  by.x = kc, by.y = "kabkota", all.x = TRUE)

    ggplot(sf::st_as_sf(peta)) +
      geom_sf(aes(fill = RR), color = "gray40", size = 0.2) +
      scale_fill_gradient2(midpoint = 1,
                           low = "#FFFFBF", high = "darkred", name = "") +
      facet_wrap(~ tahun, ncol = 5) +
      labs(title = "Relative Risk per Tahun") +
      theme_bw() +
      theme(axis.text = element_blank(), axis.ticks = element_blank(),
            panel.grid = element_blank(),
            strip.text = element_text(face = "bold"))
  })

  output$peta_prob_tahun <- renderPlot({

    req(res(), data_ready(), graph_inla())

    d   <- data_ready()
    gr  <- graph_inla()
    shp <- gr$shp
    kc  <- gr$kab_col

    fitted_df <- as.data.frame(res()$summary_fitted)
    mu <- fitted_df$mean
    sdv <- fitted_df$sd

    d$Prob_RR_gt1 <- 1 - pnorm(
      d$E,
      mean = mu,
      sd   = sdv
    )

    peta <- merge(
      shp,
      d[, c("kabkota", "tahun", "Prob_RR_gt1")],
      by.x = kc,
      by.y = "kabkota",
      all.x = TRUE
    )

    ggplot(sf::st_as_sf(peta)) +
      geom_sf(
        aes(fill = Prob_RR_gt1),
        color = "gray40",
        size = 0.2
      ) +

      scale_fill_gradient(
        low = "#FFFFBF",
        high = "#2C7BB6",
        limits = c(0,1),
        name = ""
      ) +

      facet_wrap(~tahun, ncol = 5) +

      labs(
        title = "Posterior Probability"
      ) +

      theme_bw() +
      theme(
        axis.text  = element_blank(),
        axis.ticks = element_blank(),
        panel.grid = element_blank(),
        strip.text = element_text(face = "bold")
      )
  })
}

# ============================================================
shinyApp(ui, server)
