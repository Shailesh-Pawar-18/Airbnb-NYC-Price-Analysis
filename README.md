# Airbnb NYC Price Analysis | Exploratory Data Analysis

An end-to-end EDA on 48,895 New York City Airbnb listings: clean the raw data, find what drives nightly price, and deliver a dataset that is ready for machine learning.

**Project 3 of my Data Science Pipeline.**

## Roadmap

| Part | Stage | Status |
|---|---|---|
| 1 | Exploratory Data Analysis (Python) | ✅ Complete |
| 2 | [SQL Analysis](part2-sql/) | ✅ Complete |
| 3 | Feature Engineering | 🔜 Next |
| 4 | Machine Learning (price prediction) | 🔜 Planned |

## Part 2: SQL Analysis (complete)
The cleaned data is loaded into a normalised MySQL database (`staging_listings`, `hosts`, `listings`) and 10 business questions are answered with `JOIN`, subqueries, `CASE` and a window function. Highlights: 86% of hosts have a single listing, multi-listing hosts price about 10% lower, entire homes cost about 2 to 2.3 times a private room, and revenue concentrates in corporate operators. See [`part2-sql/`](part2-sql/) for the SQL, schema diagram and findings.

## Problem statement
Raw Airbnb listing data for New York City is not ready for analysis or machine learning. It contains invalid prices ($0 listings), extreme values (prices up to $10,000 and minimum stays up to 1,250 nights), missing names and review fields, and a review date stored as text. Left as it is, these issues distort averages and hide the factors that really drive a listing's nightly price.

## Objectives
- Clean the 48,895-listing dataset: fix missing values, invalid prices and extreme outliers.
- Explore price by room type, borough and numeric features.
- Deliver a clean, validated dataset (48,631 rows) that is ready for machine learning.

## Dataset
`data/AB_NYC_2019.csv`: 48,895 listings, 16 columns (NYC Airbnb listings, 2019; [NYC Airbnb Open Data on Kaggle](https://www.kaggle.com/datasets/dgomonov/new-york-city-airbnb-open-data)).

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
├── part1-eda/
│   ├── Part_1_EDA.ipynb          analysis notebook
│   ├── Airbnb_NYC_Price_Analysis_EDA.pptx
│   └── Airbnb_NYC_Price_Analysis_EDA.pdf
└── part2-sql/
    ├── README.md
    ├── airbnb_sql.sql            schema, data quality checks, 10 business questions
    └── schema_diagram.png
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
Python, Pandas, NumPy, Matplotlib, Seaborn, Jupyter Notebook, MySQL, MySQL Workbench

---
Author: **Shailesh Pawar** | [LinkedIn](https://linkedin.com/in/shaileshpawar-cse) | [GitHub](https://github.com/Shailesh-Pawar-18)
