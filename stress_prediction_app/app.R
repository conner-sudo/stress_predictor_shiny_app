suppressPackageStartupMessages(library(gamlss))
suppressPackageStartupMessages(library(bslib))
suppressPackageStartupMessages(library(shiny))
suppressPackageStartupMessages(library(mgcv))

# Load model & data 
bundle_path <- "stress_prediction_model.rds"
bundle <- readRDS(bundle_path)

if (!is.list(bundle) || is.null(bundle$model)) {
  stop("RDS file was not saved as a list bundle. Re-save using: saveRDS(list(model = final_model, stress.clean = stress.clean), ...)")
}

model        <- bundle$model
stress.clean <- bundle$stress.clean

assign("stress.clean", stress.clean, envir = .GlobalEnv)

# Train productivity estimator (GAM)
# Productivity is a key predictor of stress in the main model, but we don't want to ask users to input it directly.
# Instead, we train a separate GAM to estimate productivity based on lifestyle factors, and feed that into the main model.

productivity_model <- gam(
  productivity ~ s(sleep_hours, bs = "tp", k = 5) + 
                 s(leisure_screen_hours, bs = "tp", k = 5) + 
                 s(work_screen_hours, bs = "tp", k = 5) + 
                 s(exercise_minutes_per_week, bs = "tp", k = 5) + 
                 s(social_hours_per_week, bs = "tp", k = 5) + 
                 s(age, bs = "tp", k = 5) +
                 gender + occupation + work_mode,
  data = stress.clean,
  family = betar()
)

estimate_productivity <- function(sleep_hours, leisure_screen_hours, work_screen_hours, 
                                  exercise_minutes_per_week, social_hours_per_week, age,
                                  gender, occupation, work_mode) {
  pred_data <- data.frame(
    sleep_hours,
    leisure_screen_hours,
    work_screen_hours,
    exercise_minutes_per_week,
    social_hours_per_week,
    age,
    gender = factor(gender, levels = c("Male", "Female", "Non-binary/Other")),
    occupation = factor(occupation, levels = c("Unemployed", "Retired", "Student", "Self-employed", "Employed")),
    work_mode = factor(work_mode, levels = c("Remote", "Hybrid", "In-person"))
  )
  pred <- predict(productivity_model, newdata = pred_data, type = "response")
  pmin(pmax(pred, 0), 1)
}

# Helpers 
stress_colour <- function(score) {
  if (is.na(score)) return("#6c757d")
  if (score < 0.33) return("#2ecc71")
  if (score < 0.66) return("#f39c12")
  return("#e74c3c")
}

stress_band <- function(score) {
  if (is.na(score)) return("Unknown")
  if (score < 0.33) return("Low Stress")
  if (score < 0.66) return("Moderate Stress")
  if (score < 0.90) return("High Stress")
  return("Severe Stress")
}

# UI 
ui <- page_sidebar(
  title = "Stress Level Predictor",
  theme = bs_theme(bootswatch = "flatly"),

  sidebar = sidebar(
    width = 320,

    h5("Demographics"),
    numericInput("age", "Age", value = 30, min = 16, max = 90, step = 1),
    selectInput("gender", "Gender",
                choices = c("Male", "Female", "Non-binary/Other")),
    selectInput("occupation", "Occupation",
                choices = c("Unemployed", "Retired", "Student",
                            "Self-employed", "Employed")),
    selectInput("work_mode", "Work Mode",
                choices = c("Remote", "Hybrid", "In-person")),

    hr(),

    h5("Sleep"),
    sliderInput("sleep_hours", "Sleep Hours (per night)",
                min = 2, max = 12, value = 7, step = 0.5),

    hr(),

    h5("Screen Time"),
    sliderInput("work_screen_hours", "Work Screen Hours (per day)",
                min = 0, max = 16, value = 6, step = 0.5),
    sliderInput("leisure_screen_hours", "Leisure Screen Hours (per day)",
                min = 0, max = 16, value = 3, step = 0.5),

    hr(),

    h5("Lifestyle"),
    sliderInput("exercise_minutes_per_week", "Exercise (minutes/week)",
                min = 0, max = 600, value = 150, step = 10),
    sliderInput("social_hours_per_week", "Social Hours (per week)",
                min = 0, max = 40, value = 10, step = 0.5),

    hr(),
    actionButton("predict_btn", "Predict My Stress",
                 class = "btn-primary w-100")
  ),

  layout_columns(
    col_widths = c(6, 6, 12),

    card(
      card_header("Predicted Stress Index"),
      card_body(
        uiOutput("stress_gauge"),
        uiOutput("stress_label")
      )
    ),

    card(
      card_header("What This Means"),
      card_body(uiOutput("interpretation"))
    ),

    card(
      card_body(
        tags$small(class = "text-muted",
          "This tool uses a GAMLSS Beta One-Inflated regression model trained on ",
          "survey data. Predictions are statistical estimates, not clinical diagnoses. ",
          "If you are experiencing significant distress, please speak with a healthcare professional."
        )
      )
    )
  )
)

# Server
server <- function(input, output, session) {

  prediction <- eventReactive(input$predict_btn, {

    new_data <- data.frame(
      age                       = as.numeric(input$age),
      gender                    = factor(input$gender,
                                         levels  = c("Male", "Female", "Non-binary/Other")),
      occupation                = factor(input$occupation,
                                         levels  = c("Unemployed", "Retired", "Student",
                                                     "Self-employed", "Employed")),
      work_mode                 = factor(input$work_mode,
                                         levels  = c("Remote", "Hybrid", "In-person")),
      sleep_hours               = as.numeric(input$sleep_hours),
      work_screen_hours         = as.numeric(input$work_screen_hours),
      leisure_screen_hours      = as.numeric(input$leisure_screen_hours),
      exercise_minutes_per_week = as.numeric(input$exercise_minutes_per_week),
      social_hours_per_week     = as.numeric(input$social_hours_per_week),
      # Feed the estimated productivity from the GAM into the main model
      productivity              = estimate_productivity(
                                      input$sleep_hours,
                                      input$leisure_screen_hours,
                                      input$work_screen_hours,
                                      input$exercise_minutes_per_week,
                                      input$social_hours_per_week,
                                      input$age,
                                      input$gender,
                                      input$occupation,
                                      input$work_mode
                                    )
    )

    pred <- withCallingHandlers(
      tryCatch(
        predict(model, newdata = new_data, what = "mu", type = "response"),
        error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NA_real_ }
      ),
      warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
    )

    round(as.numeric(pred), 4)
  })

  # Gauge 
  output$stress_gauge <- renderUI({
    score <- prediction()
    pct   <- round(score * 100, 1)
    col   <- stress_colour(score)

    tagList(
      tags$div(
        style = "text-align:center; padding: 10px 0;",
        tags$span(
          style = paste0("font-size:4rem; font-weight:700; color:", col),
          paste0(pct, "%")
        ),
        tags$br(),
        tags$small(class = "text-muted", paste0("Raw index: ", score))
      ),
      tags$div(
        class = "progress",
        style = "height:22px; border-radius:12px;",
        tags$div(
          class = "progress-bar",
          role  = "progressbar",
          style = paste0(
            "width:", pct, "%;",
            "background-color:", col, ";",
            "border-radius:12px;",
            "transition: width 0.6s ease;"
          ),
          `aria-valuenow` = pct,
          `aria-valuemin` = 0,
          `aria-valuemax` = 100
        )
      )
    )
  })

  output$stress_label <- renderUI({
    score <- prediction()
    col   <- stress_colour(score)
    band  <- stress_band(score)
    tags$div(
      style = paste0(
        "text-align:center; margin-top:12px;",
        "font-size:1.2rem; font-weight:600;",
        "color:", col
      ),
      band
    )
  })

  # Interpretation 
  output$interpretation <- renderUI({
    score <- prediction()
    band  <- stress_band(score)

    switch(band,
      "Low Stress" = tagList(
        tags$p("Your predicted stress level is ", tags$strong("low"), "."),
        tags$p(
          "Your current lifestyle habits appear to be protecting your mental wellness well. ",
          "Keep maintaining your sleep routine and balanced screen time."
        )
      ),
      "Moderate Stress" = tagList(
        tags$p("Your predicted stress level is ", tags$strong("moderate"), "."),
        tags$p("There is meaningful room to reduce stress. Common levers to consider:"),
        tags$ul(
          tags$li("Improving sleep quality and duration"),
          tags$li("Reducing leisure screen time in the evenings"),
          tags$li("Increasing weekly exercise by even 30-60 minutes")
        )
      ),
      "High Stress" = tagList(
        tags$p("Your predicted stress level is ", tags$strong("high"), "."),
        tags$p("Your profile shares characteristics with individuals reporting significant distress. ",
               "Priority areas to address:"),
        tags$ul(
          tags$li(tags$strong("Sleep:"), " both hours and duration are critical stress modulators"),
          tags$li(tags$strong("Screen time:"), " work and leisure screen exposure compound stress"),
          tags$li("Consider speaking to your manager or a wellness advisor about workload")
        )
      ),
      "Severe Stress" = tagList(
        tags$p("Your predicted stress level is ", tags$strong("severe"), "."),
        tags$p(
          "Your lifestyle profile closely matches individuals at or near peak stress saturation. ",
          "This model suggests you may be in a high-risk zone for burnout."
        ),
        tags$p(tags$strong("We strongly recommend speaking with a mental health professional or your GP."))
      ),
      # Default — before button is pressed
      tags$p(
        style = "color:#6c757d;",
        "Fill in your details and click ",
        tags$strong("Predict My Stress"),
        " to see your result."
      )
    )
  })
}

# Run Shiny App
shinyApp(ui, server)