# =============================================================================
# EPPS 6356 Data Visualization · In-class workshop
# Relationships and Models: from EDA to diagnostics to quantities of interest
# Karl Ho · Fall 2026
#
# Work through this script with the handout (relationship_workshop_handout).
# Run it one Part at a time (select the lines, then Ctrl/Cmd + Enter).
# Data are read from GitHub, so no local files are needed.
# =============================================================================

# ---- Part 0: Setup ----------------------------------------------------------

required_packages <- c("tidyverse", "openxlsx", "vroom", "janitor", "GGally",
                       "easystats", "broom", "marginaleffects", "ggdist", "MASS",
                       "sandwich")
missing <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing) > 0) install.packages(missing)

library(tidyverse)
library(GGally)            # ggpairs, ggduo, ggscatmat
library(easystats)         # performance, parameters, see, correlation, report ...
library(broom)             # tidy model output
library(marginaleffects)   # predictions and comparisons
library(ggdist)            # uncertainty geoms
library(MASS, include.only = "mvrnorm")   # only mvrnorm(), so MASS::select()
                                          # does not mask dplyr::select()

# Name clash to know about: easystats loads 'insight', which has its own
# clean_names() for model objects. Called on a data frame it fails with
# "A data frame is not a valid object for this function."
# So this script always writes janitor::clean_names() / janitor::make_clean_names().

# One theme for every plot. Palatino may not exist on every computer;
# if you see font warnings, change base_family to "serif" or "".
theme_set(theme_bw(base_size = 12, base_family = "Palatino") +
            theme(plot.title = element_text(hjust = 0.5, face = "bold"),
                  legend.position = "top"))

# ---- Part 1: Data -----------------------------------------------------------

# (a) IMF economic growth, 1980-2025, for Taiwan and its regional partners.
# Source: Tan, Ho & Clark (2020), Asian Affairs: An American Review.
# NSP = the 18 countries targeted by Taiwan's New Southbound Policy (2016).
imfgrowth <- openxlsx::read.xlsx(
  "https://raw.githubusercontent.com/datageneration/gentlemachinelearning/master/data/imfgrowth.xlsx")

imf8019 <- imfgrowth |>
  rename(US = United.States) |>
  filter(Year < 2020) |>                    # actual data only, no forecasts
  mutate(decade = factor(decade))

tcuan <- imf8019 |> select(China, Taiwan, US, NSP, ASEAN)
glimpse(tcuan)

# (b) Happy Planet Index 2016, one row per country.
hpi2016 <- vroom::vroom(
  "https://raw.githubusercontent.com/datageneration/datavisualizationinpractice/main/data/happyplanetindex.csv",
  .name_repair = janitor::make_clean_names, show_col_types = FALSE) |>
  mutate(gdp_pc = readr::parse_number(gdp_capita_ppp))   # "$4,247" -> 4247

hpi2016 |>
  select(country, region, average_life_expectancy, gdp_pc,
         footprint_gha_capita, happy_planet_index) |>
  glimpse()

# (c) Optional: Happy Planet Index 2024, the file used in the lecture slides.
hpi2024 <- openxlsx::read.xlsx(
  "https://raw.githubusercontent.com/datageneration/datavisualization/master/data/HPI1.xlsx") |>
  janitor::clean_names() |>              # not clean_names(): see the note in Part 0
  filter(!is.na(hpi), !is.na(gdp_per_capita)) |>
  mutate(continent_name = c("1" = "Latin America", "2" = "N. America & Oceania",
                            "3" = "Western Europe", "4" = "Middle East & N. Africa",
                            "5" = "Africa", "6" = "South Asia",
                            "7" = "E. Europe & C. Asia", "8" = "East Asia")[as.character(continent)])
count(hpi2024, continent_name)

# ---- Part 2: Exploratory data analysis --------------------------------------

# (a) All pairs: scatterplots below, correlations above, densities on the diagonal
ggpairs(tcuan) +
  labs(title = "Economic growth (%), 1980-2019: who moves with whom?")

# (b) One block against another: Taiwan and the US (x) vs China, NSP, ASEAN (y)
ggduo(tcuan, columnsX = c("Taiwan", "US"), columnsY = c("China", "NSP", "ASEAN"),
      types = list(continuous = wrap("points", size = 0.6, alpha = 0.6))) +
  geom_smooth(method = "lm", colour = "#c0504d", linewidth = 0.5) +
  labs(x = "Economic growth (%)", y = "Economic growth (%)")

# (c) Numeric columns only, coloured by a grouping variable
ggscatmat(imf8019, columns = c("China", "Taiwan", "US", "NSP", "ASEAN"),
          color = "decade", alpha = 0.8) +
  scale_colour_brewer(palette = "Set1") +
  labs(x = "Economic growth (%)", y = "Economic growth (%)", colour = "Decade")

# (d) Correlations as a data frame (easystats::correlation), then as a heat map
hpi_vars <- hpi2016 |>
  transmute(life_exp = average_life_expectancy,
            wellbeing = average_wellbeing_0_10,
            footprint = footprint_gha_capita,
            log_gdp = log10(gdp_pc),
            hpi = happy_planet_index)

cors <- correlation(hpi_vars)
cors                                   # r, 95% CI, p-value for every pair
cors |> summary(redundant = TRUE) |> plot()

# ---- Part 3: Fit models -----------------------------------------------------

# Fit every model on the same rows, or comparisons are not fair.
hpi_m <- hpi2016 |>
  drop_na(average_life_expectancy, gdp_pc, footprint_gha_capita, region)

m1 <- lm(average_life_expectancy ~ log10(gdp_pc), data = hpi_m)
m2 <- lm(average_life_expectancy ~ log10(gdp_pc) + footprint_gha_capita, data = hpi_m)
m3 <- lm(average_life_expectancy ~ log10(gdp_pc) + footprint_gha_capita + region,
         data = hpi_m)

summary(m2)                            # the familiar table

# ---- Part 4: Diagnose with easystats ----------------------------------------

# (a) All the standard checks in one figure (needs the 'see' package)
check_model(m3)

# (b) Individual checks, as text you can quote
check_heteroscedasticity(m3)
check_collinearity(m3)
check_outliers(m3)
check_normality(m3)

# If the variance is not constant, keep the estimates but use robust
# (heteroscedasticity-consistent) standard errors for the intervals:
model_parameters(m3, vcov = "HC3")

# (c) Compare models: R2, adjusted R2, AIC, BIC, RMSE, ...
compare_performance(m1, m2, m3, rank = TRUE)
plot(compare_performance(m1, m2, m3))  # spider plot; larger area = better

# (d) An interactive report of one model, in a new browser tab
# model_dashboard(m3)

# ---- Part 5: Show the model, not the table ----------------------------------

# (a) easystats: parameters table and plot
model_parameters(m3)
plot(model_parameters(m3))

# (b) The same idea by hand (Gelman, Pasarica & Dodhia 2002): three models, one axis
coefs <- list(`Model 1` = m1, `Model 2` = m2, `Model 3` = m3) |>
  map(\(m) tidy(m, conf.int = TRUE)) |>
  list_rbind(names_to = "model") |>
  filter(term != "(Intercept)") |>
  mutate(term = term |>
           str_replace("log10\\(gdp_pc\\)", "log10 GDP per capita") |>
           str_replace("footprint_gha_capita", "Ecological footprint (gha)") |>
           str_remove("region"),
         term = fct_reorder(term, estimate))

ggplot(coefs, aes(estimate, term, colour = model)) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high),
                  position = position_dodge(width = 0.5)) +
  labs(x = "Change in life expectancy (years), 95% CI", y = NULL, colour = NULL,
       title = "Income matters less once region is held constant",
       caption = "Reference region: Americas. Source: Happy Planet Index 2016")

# (c) One model per group (Bowers & Drake 2005)
slopes <- hpi_m |>
  group_by(region) |>
  group_modify(\(d, k) tidy(lm(average_life_expectancy ~ log10(gdp_pc), data = d),
                            conf.int = TRUE)) |>
  filter(term != "(Intercept)") |>
  ungroup() |>
  left_join(count(hpi_m, region), by = "region")

ggplot(slopes, aes(estimate, fct_reorder(region, estimate))) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high)) +
  geom_text(aes(label = paste0("n = ", n)), nudge_y = 0.3, size = 3, colour = "grey40") +
  labs(x = "Years of life per 10x GDP per capita (95% CI)", y = NULL,
       title = "The income slope differs by region")

# ---- Part 6: Quantities of interest, with uncertainty -----------------------

# (a) Simulation by hand (King, Tomz & Wittenberg 2000)
# m2 has 3 coefficients: intercept, log10(gdp_pc), footprint.
# mvrnorm() returns one ROW per simulation and one COLUMN per coefficient,
# so 1,000 draws of 3 coefficients is a 1000 x 3 matrix. Each row is one
# plausible set of coefficients; vcov(m2) makes them vary together the way
# the estimates do.
set.seed(6356)
draws <- mvrnorm(1000, mu = coef(m2), Sigma = vcov(m2))
dim(draws)                                 # 1000 3
colnames(draws)
head(draws, 3)

# A scenario is one value per coefficient, in the same order as colnames(draws):
# 1 (for the intercept), log10 GDP, and the footprint held at its median.
fp_med <- median(hpi_m$footprint_gha_capita)
x_poor <- c(1, log10(5000),  fp_med)
x_rich <- c(1, log10(50000), fp_med)

# (1000 x 3) %*% (3 x 1) = 1000 x 1: for every draw,
# intercept + slope * log10(GDP) + footprint slope * median footprint
ev_poor <- as.numeric(draws %*% x_poor)    # 1000 expected values at $5,000
ev_rich <- as.numeric(draws %*% x_rich)    # 1000 expected values at $50,000
fd <- ev_rich - ev_poor                    # 1000 first differences

quantile(fd, c(0.025, 0.5, 0.975)) |> round(1)

# (b) Plot the whole distribution
tibble(fd = fd) |>
  ggplot(aes(x = fd)) +
  stat_halfeye(fill = "#9ecae1", .width = c(0.66, 0.95)) +
  labs(x = "Difference in expected life expectancy (years), $50,000 vs $5,000",
       y = NULL, title = "1,000 simulated first differences") +
  theme(axis.text.y = element_blank())

# (c) Predicted values (one country) are far more uncertain than expected values
pred_poor <- ev_poor + rnorm(1000, 0, sigma(m2))
tibble(value = c(ev_poor, pred_poor),
       type = rep(c("Expected value", "Predicted value"), each = 1000)) |>
  ggplot(aes(x = value, y = type)) +
  stat_dots(quantiles = 50, fill = "#1f4e79", colour = NA) +
  labs(x = "Life expectancy (years) at GDP per capita = $5,000", y = NULL,
       title = "50 equally likely outcomes in each row")

# (d) The same quantities with marginaleffects
grid <- datagrid(model = m2,
                 gdp_pc = exp(seq(log(600), log(100000), length.out = 50)))
predictions(m2, newdata = grid) |>
  ggplot(aes(gdp_pc, estimate)) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), fill = "#9ecae1", alpha = 0.6) +
  geom_line(colour = "#1f4e79", linewidth = 1) +
  geom_rug(data = hpi_m, aes(x = gdp_pc), inherit.aes = FALSE, alpha = 0.4) +
  scale_x_log10(labels = scales::label_dollar()) +
  labs(x = "GDP per capita (PPP $, log scale)", y = "Expected life expectancy (years)",
       title = "Expected values with 95% intervals")

avg_comparisons(m2, variables = list(gdp_pc = c(5000, 50000)))

# ---- Part 7: Your turn ------------------------------------------------------

# The original example in relationship_model01.R:
m_hpi <- lm(happy_planet_index ~ log(population) + happy_life_years, data = hpi2016)

# 1. Run check_model(m_hpi). Which panels look worst?
# 2. Run model_parameters(m_hpi) and plot it.
# 3. The HPI is computed from wellbeing, life expectancy, inequality and footprint.
#    Why is a model of the HPI on happy life years hard to interpret?
# 4. Write one sentence, with an interval, for the effect of 10 more happy life years.
# 5. Post your outputs on your website
