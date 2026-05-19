# Stress Predictor Shiny App
![R](https://img.shields.io/badge/R-4.5+-blue.svg)
![Modeling](https://img.shields.io/badge/Modeling-caret-yellow.svg)
![Data Visualization](https://img.shields.io/badge/Data_Visualization-ggplot2-red.svg)
![Statistical Modeling](https://img.shields.io/badge/Statistical_Modeling-gamlss-purple.svg)

[![Live App](https://img.shields.io/badge/Live-Shiny_App-blue?style=for-the-badge&logo=R)](https://connerspear.shinyapps.io/stress_prediction_app/)
![thumbnail](https://github.com/conner-sudo/stress_predictor_shiny_app/blob/main/images/thumbnail_stress_app.png)

## Overview
This repository contains the code and documentation for a production-ready **R Shiny application** designed to predict psychological stress levels based on lifestyle factors. 

The core predictive engine achieves an exceptionally high **$R^2$ of 0.81**, utilizing advanced statistical modeling (Generalized Additive Models - GAMs) to handle the complex, non-linear realities of behavioral data.

## 🧠 Statistical & Machine Learning Architecture

This project moves beyond standard linear regression to properly address the nuances of psychological survey data. 

### 1. The Main Model: One-Inflated Beta GAM
Standard Gaussian distributions fall apart when predicting bounded behavioral metrics like stress (measured 0-100%). Furthermore, self-reported stress data suffers from a heavy ceiling effect—when people feel overwhelmed, they tend to report maximum stress (100%) rather than calculating a nuanced percentage. 

To statistically account for this massive density of data stacked exactly at 1.0, the app employs a **One-Inflated Beta Generalized Additive Model**. 
* **Beta distribution:** Captures the continuous 0-1 (or 0-100%) bounded nature of the data.
* **One-inflation:** Explicitly models the probability mass at the absolute maximum stress ceiling.
* **GAM smoothing functions:** Captures non-linear relationships (e.g., the U-shaped effect of sleep deprivation vs. oversleeping on stress levels).

### 2. UX-Driven Nested Architecture
A major independent variable in the main stress model is *Productivity* (a continuous 0-1 metric). However, asking users to rate their own productivity on a strict 0-1 decimal scale is highly unintuitive and leads to poor UX and noisy inputs.

To solve this, the application uses a **Nested Model Architecture**:
* A **secondary GAM** acts as an inference layer. It takes tangible, intuitive user inputs and predicts the user's underlying 0-1 Productivity score.
* This predicted productivity score is then automatically fed into the **primary Stress GAM** alongside other inputs to generate the final Stress point estimate (1-100%). 
* **Result:** The integrity of the complex primary model is preserved without sacrificing user experience.

## 📊 Features & Predictors
The models process a variety of lifestyle variables to generate the final prediction:
* **Demographics:** Age, Gender, Occupation (Student, Employed, Retired, etc.)
* **Habits:** Sleep hours
* **Digital Consumption:** Leisure screen hours, Work screen hours
* **Inferred Metrics:** Productivity score (generated via nested model)

## 🚀 Why this project matters
For employers reviewing this repository, this project demonstrates:
1. **Advanced Modeling:** Ability to identify data distribution quirks (ceiling effects) and apply the correct advanced statistical technique (One-Inflated Beta GAMs) rather than relying on out-of-the-box linear models.
2. **Product & UX Thinking:** Recognizing that a technically sound model is useless if the required user inputs are unintuitive, and engineering a nested-model solution to bridge the gap between rigorous math and user experience.
3. **End-to-End Deployment:** Taking an idea from raw data processing and model tuning in R, to building a clean UI, and deploying it as a live, interactive web application via Shiny.
