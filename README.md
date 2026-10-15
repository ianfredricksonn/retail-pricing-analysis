Retail Pricing & Revenue Analysis
SQL | R | Excel | Econometric Modeling

Project Overview

This project analyzes approximately two years of UK online retail transactions to investigate product sales patterns, pricing behavior, and the relationship between prices and demand.

Using PostgreSQL, R, and Excel, I developed an end-to-end analytical workflow that transforms raw transaction data into an interactive pricing decision model.

The project combines SQL-based data preparation, econometric estimation of price elasticity, robustness testing, product segmentation, and scenario modeling to evaluate how hypothetical price changes could affect sales volume and revenue.

The primary objective: Identify differences in estimated price sensitivity across retail products and turn the findings into an accessible decision-support tool.

Tools & Technologies

| Technology       | Application
====================================================================================
| PostgreSQL / SQL | Data cleaning, validation, aggregation, and exploratory analysis
| R / tidyverse    | Data manipulation, descriptive statistics, and visualization
| R / fixest       | Fixed-effects regression modeling and clustered standard errors
| ggplot2          | Statistical visualizations and model comparisons
| Microsoft Excel  | Interactive product selection, XLOOKUP, scenario calculations, and dashboard development

Dataset

The project uses the UCI Online Retail transaction datasets covering December 2009 through December 2011.

Two source files were combined into a PostgreSQL database containing 1,067,371 transaction-line records.

The original dataset includes:
=========================================================
| Variable     | Description
| invoice      | Transaction invoice identifier
| stock_code   | Product identifier
| description  | Product description
| quantity     | Units associated with a transaction line
| invoice_date | Transaction date and time
| price        | Unit transaction price
| customer_id  | Customer identifier
| country      | Customer or transaction country

The dataset includes merchandise sales, cancellations, returns, inventory adjustments, and other irregular transactions requiring investigation before modeling customer demand.

1. SQL Data Preparation

Data Quality Assessment

Initial SQL exploration identified several important data-quality issues.

| Issue | Initial findings
============================================================
| Missing/blank customer IDs                        | 243,007
| Missing/blank descriptions                        | 4,382
| Negative-quantity observations                    | 22,950
| Negative quantities with cancellation invoices    | 19,493
| Negative quantities without cancellation invoices | 3,457
| Zero-price observations                           | 6,202
| Negative-price observations                       | 5

Exact duplicate transaction lines were also identified. Because the dataset lacks a unique transaction-line identifier, identical records cannot always be conclusively classified as erroneous duplicates.

Cleaning Methodology

The original imported data was preserved in the "raw_transactions" table. Cleaning and analytical transformations were performed separately for traceability.

Key considerations included:

- Missing customer IDs: Retained where transactions contained usable sales information, while restricting customer-level analysis to identifiable customers.
- Cancellations and returns: Distinguished from ordinary sales using invoice identifiers and transaction quantities.
- Inventory adjustments: Investigated descriptions associated with damaged, missing, or written-off merchandise.
- Nonpositive prices: Excluded from the primary merchandise pricing analysis where unsuitable for demand modeling.
- Duplicate records: Investigated exact matches across transaction fields and documented the assumptions used when removing duplicates.

Analytical Dataset

SQL aggregation produced a product-month dataset containing approximately 68,182 observations, representing 4,916 products across 25 months.

Key product-month measures included:

- Monthly order frequency
- Units sold
- Average and median transaction prices
- Minimum and maximum prices
- Price dispersion
- Gross sales revenue
- Number of identifiable customers

This aggregated dataset formed the basis for the R analysis.

2. Exploratory Data Analysis in R

Initial analysis examined the distributions of product prices, sales quantities, and revenue.

Price Distribution

Product prices were strongly right-skewed, with most product-month observations concentrated at relatively low prices and a small number of extreme observations.

see --> (outputs/figures/Avg_Product_Prices_log.png)

The distribution motivated additional investigation into unusual transaction prices and potential inconsistencies in product descriptions, packaging, or unit definitions.

Within-Product Price Variation

Because the objective was to estimate the relationship between prices and quantities, variation in prices for the same product over time was especially important.

Exploratory checks identified substantial variation for certain stock codes. Some extreme observations potentially reflected unusual transactions or changes in the underlying product definition rather than ordinary retail price adjustments.

These findings motivated fixed-effects modeling and robustness checks.

3. Price Elasticity Estimation

Price elasticity was estimated using log-log regression models.

The general specification is:

ln(Quantity) = α + β ln(Price) + ε

In this model, β represents the estimated percentage change in quantity associated with a 1% change in price.

Model Comparison

| Specification | Estimated price coefficient
=========================================================
| Pooled OLS                                    | −0.777
| Product fixed effects                         | −1.963
| Product + month fixed effects                 | −2.061
| Product + month fixed effects, trimmed sample | −2.384

Pooled OLS: The initial model found a negative price–quantity association of approximately −0.78. However, pooling different products together can confound price differences between products with price changes within individual products.

Product fixed effects: Controlling for time-invariant product characteristics increased the magnitude of the estimated relationship to approximately −1.96.

Product and month fixed effects: Including common calendar-month effects produced an estimate of approximately −2.06.

The preferred fixed-effects specifications used standard errors clustered by product, accounting for dependence among observations belonging to the same stock code.

Robustness Testing

To assess sensitivity to extreme prices, I calculated each product-month's average price relative to that product's median price.

Observations outside the 1st and 99th percentiles of the relative-price distribution were excluded in a robustness specification.

The resulting estimate was approximately −2.38, compared with −2.06 in the untrimmed specification.

The negative relationship persisted after trimming, although its magnitude changed. This indicates that the findings are sensitive to sample construction and should be interpreted with appropriate caution.

4. Price Sensitivity by Product Segment

To examine whether pricing relationships differed across products, I estimated models using product characteristics.

Segmentation by Typical Price

Products were divided into low-, medium-, and high-price groups based on their typical selling prices.

Estimated price coefficients were relatively similar across the groups, generally ranging from approximately −2.31 to −2.43 in the interaction specification.

This suggested that typical price level alone did not explain substantial differences in estimated price sensitivity.

Segmentation by Sales Volume

Products were also divided into three groups based on typical monthly sales volume.

The interaction model produced the following estimates:

| Sales Volume Tier | Estimated Elasticity
=========================================
| Low Volume  | −2.00 |
| Mid Volume  | −2.47 |
| High Volume | −2.73 |

see --> (outputs/figures/Distribution_Avg_Product_Prices.png)

Key finding: Higher-volume products exhibited a stronger negative price–quantity association than lower-volume products.

The high-volume group's estimated elasticity magnitude was approximately 37% larger than that of the low-volume group.

These results suggest that sales-volume segmentation may be more informative than typical product price when examining heterogeneity in the estimated pricing relationship.

However, these are observational estimates, not definitive causal effects of changing prices.

5. Revenue Scenario Analysis

Estimated sales-volume-tier elasticities were used to construct hypothetical pricing scenarios.

Under a constant-elasticity assumption:

Quantity Ratio = (1 + Price Change)^Elasticity

Revenue Ratio = (1 + Price Change) × Quantity Ratio

Scenarios evaluated price adjustments from −20% to +20%, in five-percentage-point increments.

see --> (outputs/figures/Revenue_Effects_Price_Changes.png)

### Scenario Interpretation

All three estimated elasticities have magnitudes greater than one.

Consequently, the constant-elasticity scenario model predicts that price increases reduce revenue and price decreases increase revenue over the evaluated range.

For example, under the high-volume elasticity estimate of approximately −2.73:

- A 10% price decrease implies an approximately 20% revenue increase.
- A 10% price increase implies an approximately 15% revenue decrease.

These results are model-implied scenarios rather than validated causal forecasts. They illustrate the implications of the estimated coefficients under the assumed functional relationship 

6. Interactive Excel Pricing Decision Model

To make the econometric findings more accessible, I developed an interactive Excel dashboard.

The dashboard allows a user to:

1. Select an individual product using a description and stock-code dropdown.
2. Retrieve its typical selling price and monthly sales volume.
3. Identify its sales-volume segment and corresponding estimated elasticity.
4. Enter a hypothetical percentage price change.
5. Calculate implied quantity and revenue changes.
6. Compare five predefined pricing scenarios using a table and dynamic chart.

Dashboard Features

- Product selection with data validation
- Dynamic product lookups using `XLOOKUP`
- Elasticity estimates linked to sales-volume tiers
- Constant-elasticity scenario formulas
- Baseline versus proposed monthly revenue comparison
- Conditional formatting for positive and negative revenue impacts
- Dynamic revenue-impact visualization

The dashboard converts the R modeling results into a practical tool for exploring hypothetical pricing decisions.

Note: The Excel model estimates revenue changes, not profit changes. Important: Product-level cost and margin data are not included.

#7. Key Findings

1. Price and sales volume are negatively associated. 
Across multiple model specifications, higher product prices were associated with lower monthly units sold.

2. Controlling for product differences substantially changes the estimates. 
The pooled coefficient of approximately −0.78 became substantially more negative after introducing product and month fixed effects.

3. The negative relationship persists after outlier trimming.  
The trimmed fixed-effects specification produced an estimate of approximately −2.38.

4. Sales-volume segmentation reveals meaningful heterogeneity.
Higher-volume products exhibited larger estimated price sensitivity than lower-volume products.

5. Econometric results can be translated into interactive decision-support tools.  
The Excel dashboard demonstrates how statistical findings can inform structured, hypothetical pricing comparisons.

8. Methodological Limitations

Several limitations should be considered when interpreting the findings.

Observational data: Prices are not randomly assigned. Demand shocks, promotions, inventory conditions, product lifecycle effects, and other unobserved factors may influence both prices and quantities. Fixed effects reduce some sources of confounding but do not establish causality.

Product definitions: Stock codes may contain changes in packaging, descriptions, or unit definitions that affect comparisons over time.

Aggregation: Product-month averages may conceal transaction-level price variation and other factors affecting demand.

Scenario assumptions: Revenue projections assume constant elasticity within each sales-volume segment and do not model changes in competition, inventory, or customer behavior.

Profitability: The dataset does not provide reliable product-level costs or profit margins. Therefore, the analysis cannot identify profit-maximizing prices.

The project is best interpreted as an investigation of historical price–quantity relationships and a demonstration of model-based scenario analysis.

9. Repository Structure

retail-pricing-analysis/
├── data/
│   ├── raw/
│   └── processed/
├── sql/
│   └── SQL preparation and analysis scripts
├── r_analysis/
│   ├── pricing_analysis.R
│   └── r_analysis.Rproj
├── excel/
│   └── Excel pricing decision workbook
├── outputs/
│   └── figures/
│       ├── price_distribution.png
│       ├── elasticity_by_volume.png
│       └── revenue_scenarios.png
└── README.md

10. Reproducing the Analysis

Requirements

- PostgreSQL
- R and RStudio
- R packages: `tidyverse`, `fixest`, and `scales`
- Microsoft Excel with `XLOOKUP` support

Workflow

1. Obtain the source Online Retail datasets and prepare the PostgreSQL database.
2. Run the SQL scripts in their documented order to validate, clean, and aggregate the transaction data.
3. Export the product-month analytical dataset to "data/processed/".
4. Open "r_analysis/r_analysis.Rproj" in RStudio.
5. Run "pricing_analysis.R" to reproduce the descriptive analysis, regression models, and revenue scenarios.
6. Open the Excel workbook in the "excel/" folder to explore product-specific pricing scenarios.

The R analysis imports the product-month dataset using a relative file path:

```r
product_month <- read_csv("../data/processed/product_month.csv")
```

Conclusion

This project demonstrates an end-to-end analytical workflow integrating SQL data preparation, econometric modeling in R, and interactive scenario analysis in Excel.

The central finding is that estimated price sensitivity differs across sales-volume segments, with higher-volume products exhibiting stronger negative price–quantity relationships.

By combining statistical analysis with an interactive Excel model, the project illustrates how historical retail data can be transformed into accessible, decision-oriented insights while recognizing the limitations of observational modeling.
