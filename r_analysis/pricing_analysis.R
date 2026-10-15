# ============================================================
# SETUP
# ============================================================

library(tidyverse)
library(fixest)
library(scales)

# --------------------------------------------------
# 2. Import Cleaned Data
# --------------------------------------------------

product_month <- read_csv("../data/processed/product_month.csv")

# Working directory
#setwd("C:/Users/ianty/Desktop/retail-pricing-analysis/r analysis")

# ============================================================
# DESCRIPTIVE STATISTICS
# ============================================================

summary(product_month)
product_month %>%
  summarise(
    observations = n(),
    products = n_distinct(stock_code),
    months = n_distinct(month),
    
    median_units = median(units_sold),
    mean_units = mean(units_sold),
    p90_units = quantile(units_sold, 0.90),
    p99_units = quantile(units_sold, 0.99),
    max_units = max(units_sold),
    
    median_price = median(avg_price),
    mean_price = mean(avg_price),
    p90_price = quantile(avg_price, 0.90),
    p99_price = quantile(avg_price, 0.99),
    max_price = max(avg_price)
  )
ggplot(product_month, aes(x = units_sold)) +
  geom_histogram(bins = 50) +
  labs(
    title = "Distribution of Monthly Product Sales",
    x = "Units Sold per Product-Month",
    y = "Count"
  )

ggplot(product_month, aes(x = log1p(units_sold))) +
  geom_histogram(bins = 50) +
  labs(
    title = "Distribution of Monthly Product Sales (Log Scale)",
    x = "log(1 + Units Sold)",
    y = "Count"
  )

ggplot(product_month, aes(x = avg_price)) +
  geom_histogram(bins = 50) +
  labs(
    title = "Distribution of Average Product Prices",
    x = "Average Price",
    y = "Count"
  )

ggplot(product_month, aes(x = log(avg_price))) +
  geom_histogram(bins = 50) +
  labs(
    title = "Distribution of Average Product Prices (Log Scale)",
    x = "log(Average Price)",
    y = "Count"
  )

product_month %>%
  summarise(
    zero_price = sum(avg_price == 0),
    price_below_01 = sum(avg_price < 0.10),
    price_below_1 = sum(avg_price < 1),
    price_above_100 = sum(avg_price > 100),
    price_above_1000 = sum(avg_price > 1000)
  )

product_month %>%
  filter(avg_price == 0) %>%
  select(
    month,
    stock_code,
    description,
    orders,
    customers,
    units_sold,
    avg_price,
    median_price,
    min_price,
    max_price,
    gross_sales_revenue
  )
ggplot(product_month, aes(x = avg_price)) +
  geom_histogram(binwidth = 0.5, boundary = 0) +
  coord_cartesian(xlim = c(0, 25)) +
  labs(
    title = "Distribution of Average Product Prices",
    subtitle = "Display limited to £0–£25; observations above £25 retained in data",
    x = "Average Price (£)",
    y = "Product-Month Observations"
  )

model_data <- product_month %>%
  filter(avg_price > 0) %>%
  mutate(
    log_units = log(units_sold),
    log_price = log(avg_price),
    year = lubridate::year(month),
    month_num = lubridate::month(month)
  )

model_data %>%
  summarise(
    observations = n(),
    products = n_distinct(stock_code),
    months = n_distinct(month),
    min_price = min(avg_price),
    max_price = max(avg_price),
    min_units = min(units_sold),
    max_units = max(units_sold)
  )

model_1 <- lm(log_units ~ log_price, data = model_data)

summary(model_1)

model_1 <- lm(
  log_units ~ log_price,
  data = model_data
)

summary(model_1)

plot(
  model_data$log_price,
  model_data$log_units,
  pch = 16,
  cex = 0.25,
  xlab = "Log Average Price",
  ylab = "Log Units Sold",
  main = "Product-Month Sales vs. Price"
)

abline(model_1, lwd = 2)

model_2 <- feols(
  log_units ~ log_price | stock_code,
  data = model_data
)

summary(model_2)

nobs(model_2)

fitstat(model_2, c("r2", "wr2"))

model_3 <- feols(
  log_units ~ log_price | stock_code + month,
  data = model_data
)

summary(model_3)

model_3_cluster <- feols(
  log_units ~ log_price | stock_code + month,
  data = model_data,
  cluster = ~stock_code
)

summary(model_3_cluster)

price_variation <- model_data %>%
  group_by(stock_code) %>%
  summarise(
    observations = n(),
    min_price = min(avg_price),
    max_price = max(avg_price),
    mean_price = mean(avg_price),
    sd_price = sd(avg_price),
    price_ratio = max_price / min_price,
    .groups = "drop"
  )

price_variation %>%
  summarise(
    products = n(),
    no_price_change = sum(sd_price == 0, na.rm = TRUE),
    ratio_above_1_5 = sum(price_ratio >= 1.5, na.rm = TRUE),
    ratio_above_2 = sum(price_ratio >= 2, na.rm = TRUE),
    ratio_above_5 = sum(price_ratio >= 5, na.rm = TRUE),
    ratio_above_10 = sum(price_ratio >= 10, na.rm = TRUE),
    median_ratio = median(price_ratio, na.rm = TRUE),
    p90_ratio = quantile(price_ratio, .90, na.rm = TRUE),
    p95_ratio = quantile(price_ratio, .95, na.rm = TRUE),
    p99_ratio = quantile(price_ratio, .99, na.rm = TRUE),
    max_ratio = max(price_ratio, na.rm = TRUE)
  )

price_variation_log <- model_data %>%
  group_by(stock_code) %>%
  summarise(
    observations = n(),
    sd_log_price = sd(log_price),
    range_log_price = max(log_price) - min(log_price),
    .groups = "drop"
  )

summary(price_variation_log$sd_log_price)

# Calculate each product's typical (median) price
model_robust <- model_data %>%
  group_by(stock_code) %>%
  mutate(
    product_median_price = median(avg_price),
    relative_price = avg_price / product_median_price
  ) %>%
  ungroup()

# See distribution of relative prices
quantile(
  model_robust$relative_price,
  probs = c(.001, .005, .01, .05, .50, .95, .99, .995, .999)
)

# 1st and 99th percentile cutoffs
lower_cutoff <- quantile(model_robust$relative_price, 0.01)
upper_cutoff <- quantile(model_robust$relative_price, 0.99)

lower_cutoff
upper_cutoff

# Keep observations within the central 98% of relative prices
model_trimmed <- model_robust %>%
  filter(
    relative_price >= lower_cutoff,
    relative_price <= upper_cutoff
  )

# Check how much data remains
nrow(model_data)
nrow(model_trimmed)
nrow(model_data) - nrow(model_trimmed)

library(fixest)

model_3_trimmed <- feols(
  log_units ~ log_price | stock_code + month,
  data = model_trimmed,
  cluster = ~stock_code
)

summary(model_3_trimmed)

model_robust <- model_robust %>%
  mutate(
    price_position = case_when(
      relative_price < 0.90 ~ "Discounted (>10% below typical)",
      relative_price <= 1.10 ~ "Near typical price",
      relative_price > 1.10 ~ "Premium (>10% above typical)"
    )
  )

price_position_summary <- model_robust %>%
  group_by(price_position) %>%
  summarise(
    observations = n(),
    products = n_distinct(stock_code),
    median_units = median(units_sold),
    mean_units = mean(units_sold),
    median_price = median(avg_price),
    total_revenue = sum(gross_sales_revenue),
    .groups = "drop"
  )

price_position_summary

#low/mid/high price elasticity models

# ============================================================
# PRICE-TIER ELASTICITY ANALYSIS
# ============================================================

library(dplyr)
library(fixest)

# Calculate typical price for each product
product_prices <- model_trimmed %>%
  group_by(stock_code) %>%
  summarise(
    typical_price = median(avg_price),
    .groups = "drop"
  )

# Divide PRODUCTS into low / mid / high price terciles
product_prices <- product_prices %>%
  mutate(
    price_tier = ntile(typical_price, 3),
    price_tier = case_when(
      price_tier == 1 ~ "Low",
      price_tier == 2 ~ "Mid",
      price_tier == 3 ~ "High"
    )
  )

# Check the tiers BEFORE estimating anything
product_prices %>%
  group_by(price_tier) %>%
  summarise(
    products = n(),
    min_typical_price = min(typical_price),
    median_typical_price = median(typical_price),
    max_typical_price = max(typical_price)
  )

# Attach price tier to each product-month observation
tier_data <- model_trimmed %>%
  left_join(
    product_prices %>% select(stock_code, price_tier),
    by = "stock_code"
  )

# Low-price products
model_low <- feols(
  log_units ~ log_price | stock_code + month,
  data = tier_data %>% filter(price_tier == "Low"),
  cluster = ~stock_code
)

# Mid-price products
model_mid <- feols(
  log_units ~ log_price | stock_code + month,
  data = tier_data %>% filter(price_tier == "Mid"),
  cluster = ~stock_code
)

# High-price products
model_high <- feols(
  log_units ~ log_price | stock_code + month,
  data = tier_data %>% filter(price_tier == "High"),
  cluster = ~stock_code
)

summary(model_low)
summary(model_mid)
summary(model_high)

# Make Mid the reference category
tier_data$price_tier <- factor(
  tier_data$price_tier,
  levels = c("Mid", "Low", "High")
)

model_tier_interaction <- feols(
  log_units ~ log_price * price_tier | stock_code + month,
  data = tier_data,
  cluster = ~stock_code
)

summary(model_tier_interaction)

# ============================================================
# SALES VOLUME HETEROGENEITY ANALYSIS
# ============================================================

library(dplyr)
library(fixest)

# Calculate typical monthly sales volume for each product
product_volume <- model_trimmed %>%
  group_by(stock_code) %>%
  summarise(
    typical_monthly_units = median(units_sold),
    months_observed = n_distinct(month),
    .groups = "drop"
  )

# Divide products into three sales-volume tiers
product_volume <- product_volume %>%
  mutate(
    volume_tier = ntile(typical_monthly_units, 3),
    volume_tier = case_when(
      volume_tier == 1 ~ "Low Volume",
      volume_tier == 2 ~ "Mid Volume",
      volume_tier == 3 ~ "High Volume"
    )
  )

# Examine the resulting classifications
product_volume %>%
  group_by(volume_tier) %>%
  summarise(
    products = n(),
    min_units = min(typical_monthly_units),
    median_units = median(typical_monthly_units),
    max_units = max(typical_monthly_units),
    avg_months_observed = mean(months_observed),
    .groups = "drop"
  )

# Attach volume tier to product-month observations
volume_data <- model_trimmed %>%
  left_join(
    product_volume %>% select(stock_code, volume_tier),
    by = "stock_code"
  )

# Low-volume products
model_volume_low <- feols(
  log_units ~ log_price | stock_code + month,
  data = volume_data %>% filter(volume_tier == "Low Volume"),
  cluster = ~stock_code
)

# Mid-volume products
model_volume_mid <- feols(
  log_units ~ log_price | stock_code + month,
  data = volume_data %>% filter(volume_tier == "Mid Volume"),
  cluster = ~stock_code
)

# High-volume products
model_volume_high <- feols(
  log_units ~ log_price | stock_code + month,
  data = volume_data %>% filter(volume_tier == "High Volume"),
  cluster = ~stock_code
)

summary(model_volume_low)
summary(model_volume_mid)
summary(model_volume_high)

# Make Mid Volume the reference category
volume_data$volume_tier <- factor(
  volume_data$volume_tier,
  levels = c("Mid Volume", "Low Volume", "High Volume")
)

model_volume_interaction <- feols(
  log_units ~ log_price * volume_tier | stock_code + month,
  data = volume_data,
  cluster = ~stock_code
)

summary(model_volume_interaction)

# ============================================================
# VISUALIZATION: PRICE ELASTICITY BY SALES-VOLUME TIER
# ============================================================

# Extract coefficient estimates
b <- coef(model_volume_interaction)

# Extract clustered variance-covariance matrix
V <- vcov(model_volume_interaction)

# Calculate implied elasticities
elasticity_mid  <- b["log_price"]

elasticity_low  <- b["log_price"] +
  b["log_price:volume_tierLow Volume"]

elasticity_high <- b["log_price"] +
  b["log_price:volume_tierHigh Volume"]


# Calculate SE for each implied elasticity
se_mid <- sqrt(V["log_price", "log_price"])

se_low <- sqrt(
  V["log_price", "log_price"] +
    V["log_price:volume_tierLow Volume",
      "log_price:volume_tierLow Volume"] +
    2 * V["log_price",
          "log_price:volume_tierLow Volume"]
)

se_high <- sqrt(
  V["log_price", "log_price"] +
    V["log_price:volume_tierHigh Volume",
      "log_price:volume_tierHigh Volume"] +
    2 * V["log_price",
          "log_price:volume_tierHigh Volume"]
)


# Build plotting dataframe
elasticity_plot <- tibble(
  volume_tier = c("Low Volume", "Mid Volume", "High Volume"),
  elasticity = c(elasticity_low, elasticity_mid, elasticity_high),
  se = c(se_low, se_mid, se_high)
) %>%
  mutate(
    lower_ci = elasticity - 1.96 * se,
    upper_ci = elasticity + 1.96 * se
  )

elasticity_plot

ggplot(
  elasticity_plot,
  aes(x = reorder(volume_tier, elasticity),
      y = elasticity)
) +
  geom_point(size = 4) +
  geom_errorbar(
    aes(ymin = lower_ci, ymax = upper_ci),
    width = 0.12,
    linewidth = 0.8
  ) +
  geom_hline(
    yintercept = -1,
    linetype = "dashed",
    linewidth = 0.7
  ) +
  coord_flip() +
  labs(
    title = "Estimated Price Elasticity by Sales Volume",
    subtitle = "Product and month fixed effects; 95% confidence intervals",
    x = NULL,
    y = "Estimated Price Elasticity",
    caption = "Dashed line indicates unit elasticity (-1). Standard errors clustered by product."
  ) +
  theme_minimal(base_size = 13)

# ============================================================
# REVENUE SCENARIO ANALYSIS
# ============================================================

# Elasticities estimated from the interaction model
tier_elasticities <- tibble(
  volume_tier = c("Low Volume", "Mid Volume", "High Volume"),
  elasticity = c(-2.00, -2.47, -2.73)
)

# Price-change scenarios
revenue_scenarios <- expand_grid(
  tier_elasticities,
  price_change = seq(-0.20, 0.20, by = 0.05)
) %>%
  mutate(
    price_ratio = 1 + price_change,
    
    # Exact quantity response implied by log-log elasticity
    quantity_ratio = price_ratio ^ elasticity,
    
    quantity_change = quantity_ratio - 1,
    
    # Revenue = Price × Quantity
    revenue_ratio = price_ratio * quantity_ratio,
    revenue_change = revenue_ratio - 1
  )

revenue_scenarios %>%
  mutate(
    price_change = scales::percent(price_change, accuracy = 1),
    quantity_change = scales::percent(quantity_change, accuracy = 0.1),
    revenue_change = scales::percent(revenue_change, accuracy = 0.1)
  ) %>%
  select(
    volume_tier,
    elasticity,
    price_change,
    quantity_change,
    revenue_change
  )


log_units ~ log_price | stock_code + month

# ============================================================
# VISUALIZATION: PRICE CHANGES AND IMPLIED REVENUE
# ============================================================

ggplot(
  revenue_scenarios,
  aes(
    x = price_change * 100,
    y = revenue_change * 100,
    group = volume_tier,
    linetype = volume_tier
  )
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    linewidth = 0.6
  ) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed",
    linewidth = 0.6
  ) +
  scale_x_continuous(
    breaks = seq(-20, 20, 5),
    labels = function(x) paste0(x, "%")
  ) +
  scale_y_continuous(
    labels = function(x) paste0(x, "%")
  ) +
  labs(
    title = "Model-Implied Revenue Effects of Price Changes",
    subtitle = "Scenarios based on estimated elasticity by product sales volume",
    x = "Price Change",
    y = "Implied Revenue Change",
    linetype = "Sales Volume",
    caption = "Scenario estimates based on fixed-effects elasticity models; not causal forecasts."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "bottom"
  )

# ============================================================
# PRODUCT LOOKUP TABLE FOR EXCEL DECISION MODEL
# ============================================================

# One row per product
product_lookup <- model_trimmed %>%
  group_by(stock_code) %>%
  summarise(
    description = first(description),
    typical_price = median(avg_price),
    typical_monthly_units = median(units_sold),
    avg_monthly_units = mean(units_sold),
    months_observed = n_distinct(month),
    total_revenue = sum(gross_sales_revenue),
    .groups = "drop"
  )

# Assign products to the SAME volume tiers used in the R models
product_lookup <- product_lookup %>%
  mutate(
    volume_group = ntile(typical_monthly_units, 3),
    volume_tier = case_when(
      volume_group == 1 ~ "Low Volume",
      volume_group == 2 ~ "Mid Volume",
      volume_group == 3 ~ "High Volume"
    )
  ) %>%
  select(-volume_group) %>%
  arrange(stock_code)

# Check result
product_lookup

nrow(product_lookup)

product_lookup %>%
  count(volume_tier)