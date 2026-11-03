# Airbnb NYC Price Analysis | Exploratory Data Analysis

An end-to-end EDA on 48,895 New York City Airbnb listings: clean the raw data, find what drives nightly price, and deliver a dataset that is ready for machine learning.

**Project 2 of my Data Science Pipeline.**

## Roadmap

| Part | Stage | Status |
|---|---|---|
| 1 | Exploratory Data Analysis (Python) | ✅ Complete |
| 2 | SQL Analysis | 🔜 Planned |
| 3 | Feature Engineering | 🔜 Planned |
| 4 | Machine Learning (price prediction) | 🔜 Planned |

## Problem statement
Raw Airbnb listing data for New York City is not ready for analysis or machine learning. It contains invalid prices ($0 listings), extreme values (prices up to $10,000 and minimum stays up to 1,250 nights), missing names and review fields, and a review date stored as text. Left as it is, these issues distort averages and hide the factors that really drive a listing's nightly price.

## Objectives
- Clean the 48,895-listing dataset: fix missing values, invalid prices and extreme outliers.
- Explore price by room type, borough and numeric features.
- Deliver a clean, validated dataset (48,631 rows) that is ready for machine learning.

## Dataset
`data/AB_NYC_2019.csv`: 48,895 listings, 16 columns (NYC Airbnb listings, 2019).

| Type | Columns |
|---|---|
| Numerical | price (target), minimum_nights, number_of_reviews, reviews_per_month, calculated_host_listings_count, availability_365, latitude, longitude |
| Categorical and ID | id, host_id, name, host_name, neighbourhood_group, neighbourhood, room_type, last_review |

## Data cleaning

| Column | Issue | Action |
|---|---|---|
| Full dataset | 0 duplicate rows | None needed |
| name, host_name | 16 and 21 missing | Filled with "Unknown" |
| price | 11 listings at $0, 239 above $1,000 (max $10,000) | Removed |
| minimum_nights | Max 1,250 nights; 14 listings above 365 | Removed rows above 365 |
| last_review | Text type, 10,052 missing | Converted to datetime; gaps kept (no reviews) |
| reviews_per_month | 10,052 missing | Filled with 0 |

Result: 48,895 rows became **48,631** (264 removed, 0.5%).

## Key findings
- **Price is right-skewed:** median $105, mean $141.
- **Room type matters most:** entire homes $160, private rooms $70, shared rooms $45 (median).
- **Location matters next:** Manhattan $149 vs the Bronx $65.
- **Premium segment:** Manhattan entire homes, $190 median (about 1.8x the market median).
- **Supply is concentrated:** Manhattan and Brooklyn hold 85% of listings.
- **Numeric features are weak price predictors:** the strongest correlation is longitude (r = -0.26).
- 35.9% of listings are unavailable all year, and about 20% have never been reviewed.

## Project structure
```
Airbnb-NYC-Price-Analysis/
├── README.md
├── requirements.txt
├── .gitignore
├── data/
│   ├── AB_NYC_2019.csv           raw data
│   └── cleaned_airbnb.csv        created by running the notebook
└── part1-eda/
    ├── Part_1_EDA.ipynb          analysis notebook
    ├── Airbnb_NYC_Price_Analysis_EDA.pptx
    └── Airbnb_NYC_Price_Analysis_EDA.pdf
```

## How to run
```bash
git clone https://github.com/Shailesh-Pawar-18/Airbnb-NYC-Price-Analysis.git
cd Airbnb-NYC-Price-Analysis
pip install -r requirements.txt
jupyter notebook part1-eda/Part_1_EDA.ipynb
```
Running the notebook creates `data/cleaned_airbnb.csv`.

## Limitations
- A 2019 snapshot of listing prices, not the prices guests actually paid.
- Findings are associations in the data, not proof of cause.
- Rows above $1,000 a night and above 365 minimum nights were removed as extreme values; this is a judgment call.

## Tech stack
Python, Pandas, NumPy, Matplotlib, Seaborn, Jupyter Notebook

---

# Part 2: SQL Analysis | Airbnb NYC Price Analysis

> **The Airbnb Files, Chapter 2.** In Part 1 I cleaned the data and explored it with Python. In Part 2 I load it into a relational database and answer **10 business questions with SQL**.

![Schema](schema_diagram.png)

## Business problem
Hosts struggle to price a listing fairly in New York City. Who prices above or below the market, where is demand strong but supply thin, and what do the most successful hosts do differently? This part of the project, "Dynamic Price Recommendation for Airbnb Hosts", answers those questions with SQL before any model is built.

## Objectives
1. Build a normalised MySQL database from the cleaned EDA data.
2. Check data quality before any analysis.
3. Answer 10 business questions with `JOIN`, subqueries, `CASE`, `GROUP BY`, `HAVING` and a window function.
4. Turn the results into pricing insights for hosts.

## Data
`data/cleaned_airbnb.csv` is the output of Part 1: **48,631 listings, 16 columns** (the NYC Airbnb 2019 open dataset, [on Kaggle](https://www.kaggle.com/datasets/dgomonov/new-york-city-airbnb-open-data)).

| Table | What it holds | Rows |
|---|---|---|
| `staging_listings` | Flat landing copy of the CSV | 48,631 |
| `hosts` | Host-level attributes: `host_id` (PK), `host_name`, `calculated_host_listings_count` | 37,270 |
| `listings` | Listing-level attributes, with `host_id` as a foreign key to `hosts` | 48,631 |

Host attributes were separated from listing attributes because they describe the host, not the listing (second normal form). This supports real `JOIN` questions.

## Files
| File | Purpose |
|---|---|
| `airbnb_sql.sql` | The full workflow: schema, import, verification, population, data quality checks, 10 business questions, executive summary |
| `schema_diagram.png` | Schema diagram |

## How to run (MySQL 8.0+)
1. Open **MySQL Workbench** and run Section 1 of `airbnb_sql.sql` to create `airbnb_db` and the three tables.
2. In Section 2, change the file path in `LOAD DATA LOCAL INFILE` to where `cleaned_airbnb.csv` is on your computer. If MySQL blocks the import, run `SET GLOBAL local_infile = 1;` first. (On Windows, use forward slashes in the path.)
3. Run the remaining sections in order.

**Check your setup**

| Check | Expected |
|---|---|
| Rows in `staging_listings` and `listings` | 48,631 |
| Rows in `hosts` | 37,270 |
| Orphan listings (no matching host) | 0 |
| Listings with a missing `last_review` | 9,911 (all have zero reviews) |

## Data quality checks (Section 4c)
Six checks ran before the analysis: missing values in key columns, non-positive prices, duplicate keys, unexpected room types, impossible coordinates, and unrealistic minimum stays. All passed on the cleaned data.

## The 10 business questions

| # | Question | Technique |
|---|---|---|
| Q1 | Power hosts vs solo hosts: who owns the market? | `JOIN` + `CASE` + `GROUP BY` |
| Q2 | Which listings are priced above their borough's average? | Derived table + `JOIN` |
| Q3 | How big is the room-type price premium in each borough? | `GROUP BY` on two dimensions |
| Q4 | Which 10 hosts have the highest estimated revenue potential? | `JOIN`, derived calculation, `LIMIT` |
| Q5 | Which listings are underpriced for their demand? | Derived table benchmark |
| Q6 | Which listings are overpriced for their borough and room type? | Derived table + `JOIN` |
| Q7 | Where are the high-demand, low-supply neighbourhood hotspots? | `GROUP BY` + `HAVING` + subquery benchmarks |
| Q8 | Do hosts with many listings price differently? | Scalar subquery + `CASE` |
| Q9 | What are the 3 most expensive listings in each borough? | Window function `ROW_NUMBER() OVER (PARTITION BY ...)` |
| Q10 | Who are the premium power hosts? | Non-correlated subqueries |

## Key findings
- **Most hosts are small.** 86% of hosts (32,122 of 37,270) have a single listing. The 5,148 multi-listing hosts price about **10% lower** on average ($131 vs $147), so scale does not mean premium pricing.
- **Room type sets the price in every borough.** Entire homes cost roughly 2.0 to 2.3 times a private room. Manhattan entire homes average about **$225**.
- **Borough averages differ widely.** Manhattan averages about $179 against $85 in the Bronx.
- **Revenue is concentrated in professional operators.** The highest estimated revenue potential belongs to corporate hosts such as Blueground, Sonder and Red Awning, not individuals. (Estimated revenue is price x days unavailable, a rough proxy.)
- **Underpriced demand pockets exist.** Most of the top 20 high-demand, below-average listings are Queens private rooms priced well under the $68 average for that segment.
- **Premium hotspots:** NoHo (about $276 average), SoHo ($254) and West Village ($239) combine high prices with below-average availability.

## What hosts and the platform can do
1. **Benchmark against borough and room type, not the city average.** The gap between segments is far larger than the gap within one.
2. **Review underpriced, high-demand listings.** They are the clearest room to raise prices.
3. **Watch the $995 to $1,000 Manhattan entire homes.** They show low turnover, so they may be overpriced.
4. **Treat professional operators as a separate segment** when analysing supply and revenue.

## What I learned
- **A correlated subquery timed out** on 48,631 rows, because it recalculated the borough average for every row. Rewriting it as a derived table that computes each average once, then joining, made it fast. (Q2, Q5 and Q6 use this pattern.)
- **`ROW_NUMBER()` vs `RANK()`:** prices are capped at $1,000, so ties are common. `ROW_NUMBER()` returns exactly 3 listings per borough, while `RANK()` can return more.

## Limitations
- "Estimated revenue" uses days unavailable as a proxy for bookings. Real bookings are not in the data.
- `reviews_per_month` is used as a demand signal, which is not the same as bookings.
- Prices are capped at $1,000 after cleaning, which affects the top of the range.
- These results show patterns in a 2019 snapshot, not proven causes.

## SQL skills shown
`CREATE TABLE` with primary and foreign keys · `LOAD DATA` · normalisation · `JOIN` · derived tables · scalar and non-correlated subqueries · `CASE` · `GROUP BY` · `HAVING` · window functions · data quality checks · query optimisation

## Next: Chapter 3
Feature engineering: turn what the EDA and SQL found into model-ready features for a price prediction model.

Author: **Shailesh Pawar** | [LinkedIn](https://linkedin.com/in/shaileshpawar-cse) | [GitHub](https://github.com/Shailesh-Pawar-18)
