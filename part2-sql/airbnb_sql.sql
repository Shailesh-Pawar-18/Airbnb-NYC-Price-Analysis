-- ============================================================
-- PROJECT:        Dynamic Price Recommendation for Airbnb Hosts
-- DATASET:        NYC Airbnb Open Data (2019) — Kaggle
--                 https://www.kaggle.com/datasets/dgomonov/new-york-city-airbnb-open-data
-- FILE:           airbnb_sql.sql
-- PURPOSE:        Full SQL workflow for this project — schema creation,
--                 data import, normalization, and business analysis
--                 queries (joins, subqueries, aggregations).
--
-- AUTHOR:         Shailesh Pawar
-- LINKEDIN:       https://www.linkedin.com/in/shaileshpawar-cse
-- GITHUB:         https://github.com/Shailesh-Pawar-18
--
-- PIPELINE STAGE: Stage 2 — SQL Analysis
--                 (Data Understanding -> Data Cleaning -> EDA ->
--                  SQL -> Feature Engineering -> ML -> Deep Learning ->
--                  Dashboard -> Deployment)
--
-- SOURCE DATA:    data/cleaned_airbnb.csv
--                 (48,631 rows x 16 columns, cleaned from original
--                  48,895 rows x 16 columns — see Part_1_EDA.ipynb
--                  for full cleaning documentation)
--
-- DESIGN NOTES:
--   - 3-table normalized design: staging_listings (flat landing
--     table for CSV import) -> hosts (host-level attributes) ->
--     listings (listing-level attributes, FK to hosts)
--   - Host attributes (host_name, calculated_host_listings_count)
--     were separated from listings since they describe the HOST,
--     not the individual listing (2NF normalization)
--   - This structure supports realistic JOIN and subquery business
--     questions later in this file
-- ============================================================


-- ============================================================
-- SECTION 1: SCHEMA CREATION
-- ============================================================

CREATE DATABASE IF NOT EXISTS airbnb_db;
USE airbnb_db;

-- Drop existing tables if re-running (clean slate)
-- Order matters: listings references hosts, so drop listings first
DROP TABLE IF EXISTS listings;
DROP TABLE IF EXISTS hosts;
DROP TABLE IF EXISTS staging_listings;

-- staging_listings: flat landing table, mirrors CSV exactly.
-- Used only as an intermediate step for LOAD DATA INFILE.
CREATE TABLE staging_listings (
    id                              INT,
    name                            VARCHAR(255),
    host_id                         INT,
    host_name                       VARCHAR(100),
    neighbourhood_group             VARCHAR(50),
    neighbourhood                   VARCHAR(100),
    latitude                        DECIMAL(9,6),
    longitude                       DECIMAL(9,6),
    room_type                       VARCHAR(50),
    price                           INT,
    minimum_nights                  INT,
    number_of_reviews               INT,
    last_review                     DATE,
    reviews_per_month               DECIMAL(5,2),
    calculated_host_listings_count  INT,
    availability_365                INT
);

-- hosts: one row per unique host, normalized host-level attributes
CREATE TABLE hosts (
    host_id                         INT PRIMARY KEY,
    host_name                       VARCHAR(100),
    calculated_host_listings_count  INT
);

-- listings: one row per listing, references hosts via host_id
CREATE TABLE listings (
    id                   INT PRIMARY KEY,
    host_id              INT,
    name                 VARCHAR(255),
    neighbourhood_group  VARCHAR(50),
    neighbourhood        VARCHAR(100),
    latitude             DECIMAL(9,6),
    longitude            DECIMAL(9,6),
    room_type            VARCHAR(50),
    price                INT,
    minimum_nights       INT,
    number_of_reviews    INT,
    last_review          DATE,
    reviews_per_month    DECIMAL(5,2),
    availability_365     INT,
    CONSTRAINT fk_host
        FOREIGN KEY (host_id) REFERENCES hosts(host_id)
);


-- ============================================================
-- SECTION 2: DATA IMPORT (CSV -> staging_listings)
-- ============================================================

-- Enable LOCAL INFILE for this session (CSV is outside MySQL's
-- secure_file_priv directory, so LOCAL INFILE reads it directly
-- from the client machine instead)
SET GLOBAL local_infile = 1;

-- Load cleaned_airbnb.csv into staging_listings
-- @last_review variable converts empty strings (pandas NaT on
-- export) into proper SQL NULL, since last_review is DATE type
-- RESULT (confirmed): 48,631 rows affected, 0 skipped, 0 warnings
LOAD DATA LOCAL INFILE 'C:/path/to/Airbnb-NYC-Price-Analysis/data/cleaned_airbnb.csv'
INTO TABLE staging_listings
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, name, host_id, host_name, neighbourhood_group, neighbourhood,
 latitude, longitude, room_type, price, minimum_nights, number_of_reviews,
 @last_review, reviews_per_month, calculated_host_listings_count, availability_365)
SET last_review = NULLIF(@last_review, '');


-- ============================================================
-- SECTION 3: IMPORT VERIFICATION
-- ============================================================

-- Confirmed result: 48631 (matches cleaned_airbnb.csv row count)
SELECT COUNT(*) AS total_rows FROM staging_listings;

-- Confirmed result: sample rows look correctly aligned
-- (names, hosts, boroughs, prices, coordinates all in correct columns)
SELECT * FROM staging_listings LIMIT 5;

-- Confirmed result: 9911 NULL last_review rows
-- (the raw file has 10,052; 264 rows were removed during cleaning
-- and 141 of them had a missing last_review: 10,052 - 141 = 9,911.
-- Every one of these listings has zero reviews)
SELECT COUNT(*) AS null_last_review
FROM staging_listings
WHERE last_review IS NULL;

-- ============================================================
-- SECTION 4: POPULATE hosts AND listings FROM staging_listings
-- ============================================================

-- Step 1: Populate hosts (must happen first — listings.host_id
-- has a FK constraint referencing hosts.host_id)
--
-- staging_listings has one row PER LISTING, so host_id repeats
-- for hosts with multiple listings. GROUP BY host_id collapses
-- this to one row per unique host.
--
-- MAX() is used defensively on host_name and
-- calculated_host_listings_count — these should be constant per
-- host_id, but MAX() guards against any data inconsistency
-- without failing the insert.
INSERT INTO hosts (host_id, host_name, calculated_host_listings_count)
SELECT
    host_id,
    MAX(host_name) AS host_name,
    MAX(calculated_host_listings_count) AS calculated_host_listings_count
FROM staging_listings
GROUP BY host_id;

-- Step 2: Populate listings (host-level columns removed —
-- they now live in hosts; host_id kept as FK)
INSERT INTO listings (
    id, host_id, name, neighbourhood_group, neighbourhood,
    latitude, longitude, room_type, price, minimum_nights,
    number_of_reviews, last_review, reviews_per_month, availability_365
)
SELECT
    id, host_id, name, neighbourhood_group, neighbourhood,
    latitude, longitude, room_type, price, minimum_nights,
    number_of_reviews, last_review, reviews_per_month, availability_365
FROM staging_listings;


-- ============================================================
-- SECTION 4b: POPULATION VERIFICATION
-- ============================================================

-- Expected: 48631 (one row per listing, same as staging_listings)
SELECT COUNT(*) AS total_listings FROM listings;

-- Expected: should match COUNT(DISTINCT host_id) from staging_listings
SELECT COUNT(*) AS total_hosts FROM hosts;

-- Cross-check: distinct host_id count in staging vs hosts table
-- (these two numbers must be equal)
SELECT COUNT(DISTINCT host_id) AS distinct_host_ids_staging
FROM staging_listings;

-- Sanity check: every listing's host_id should exist in hosts
-- (FK constraint already guarantees this, but good to verify
-- explicitly — expected result: 0 orphan rows)
SELECT COUNT(*) AS orphan_listings
FROM listings l
LEFT JOIN hosts h ON l.host_id = h.host_id
WHERE h.host_id IS NULL;

-- ============================================================
-- SECTION 4c: DATA QUALITY CHECKS (on listings & hosts)
-- Purpose: Validate that populated tables are safe to run
-- business/analytical queries on — catch NULLs, invalid values,
-- duplicates, or out-of-range data before trusting any results.
-- ============================================================

-- Check 1: NULLs in business-critical columns of listings
-- (price, room_type, neighbourhood_group, availability_365 are
-- used in almost every query ahead — NULLs here would silently
-- break aggregations and JOINs)
SELECT
    SUM(price IS NULL)              AS null_price,
    SUM(room_type IS NULL)          AS null_room_type,
    SUM(neighbourhood_group IS NULL) AS null_neighbourhood_group,
    SUM(availability_365 IS NULL)   AS null_availability_365,
    SUM(host_id IS NULL)            AS null_host_id
FROM listings;

-- Check 2: Invalid price values (price should always be positive;
-- 0 or negative price is a data entry error, not a real listing)
SELECT COUNT(*) AS invalid_price_rows
FROM listings
WHERE price <= 0;

-- Check 3: Duplicate primary keys (should be impossible due to
-- PRIMARY KEY constraint, but verifying explicitly for documentation)
SELECT id, COUNT(*) AS cnt
FROM listings
GROUP BY id
HAVING cnt > 1;

SELECT host_id, COUNT(*) AS cnt
FROM hosts
GROUP BY host_id
HAVING cnt > 1;

-- Check 4: Unexpected categorical values — room_type should only
-- have 3 known categories, neighbourhood_group only 5 NYC boroughs
SELECT DISTINCT room_type FROM listings;
SELECT DISTINCT neighbourhood_group FROM listings;

-- Check 5: Latitude/longitude sanity — all coordinates should
-- fall within NYC's approximate bounding box
SELECT COUNT(*) AS out_of_bounds_coords
FROM listings
WHERE latitude NOT BETWEEN 40.4 AND 41.0
   OR longitude NOT BETWEEN -74.3 AND -73.6;

-- Check 6: minimum_nights sanity check — flag unrealistic values
-- (e.g., minimum stay longer than a year is likely a listing
-- effectively "closed" for booking, not a genuine nightly rental)
SELECT COUNT(*) AS extreme_minimum_nights
FROM listings
WHERE minimum_nights > 365;

-- ============================================================
-- DATA QUALITY CHECK RESULTS (confirmed):
--   - No NULLs in price, room_type, neighbourhood_group,
--     availability_365, host_id
--   - No invalid (<=0) prices
--   - No duplicate primary keys in listings or hosts
--   - room_type has exactly 3 expected categories
--   - neighbourhood_group has exactly 5 expected NYC boroughs
--   - No out-of-bounds latitude/longitude values
--   - No extreme minimum_nights (>365) values
-- CONCLUSION: Data is clean and safe to proceed with business
-- analysis queries (Section 5).
-- ============================================================



-- ============================================================
-- SECTION 5: BUSINESS QUESTIONS (JOINS, SUBQUERIES, AGGREGATIONS)
-- ============================================================

-- ------------------------------------------------------------
-- Q1: Power Hosts vs Solo Hosts
-- Business question: What is the average price and listing
-- count per host — and what % of hosts are "power hosts"
-- (multiple listings) vs solo hosts?
--
-- Technique: JOIN + CASE + GROUP BY
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN h.calculated_host_listings_count > 1 THEN 'Power Host'
        ELSE 'Solo Host'
    END AS host_type,
    COUNT(DISTINCT h.host_id)        AS num_hosts,
    ROUND(COUNT(DISTINCT h.host_id) * 100.0 / (SELECT COUNT(*) FROM hosts), 2) AS pct_of_hosts,
    ROUND(AVG(l.price), 2)           AS avg_price,
    ROUND(AVG(h.calculated_host_listings_count), 2) AS avg_listings_per_host
FROM hosts h
JOIN listings l ON h.host_id = l.host_id
GROUP BY host_type;


-- ------------------------------------------------------------
-- Q2: Listings priced above their own borough's average price
-- Business question: Which listings are overpriced relative to
-- their own borough — candidates for price review?
--
-- Technique: Subquery (derived table) + JOIN
-- NOTE: Originally written as a correlated subquery (re-evaluating
-- borough average once per row), but this caused a connection
-- timeout at 48,631 rows — O(n) row-by-row re-computation is too
-- expensive here. Refactored into a derived table that computes
-- each borough's average ONCE (5 boroughs), then joins it back —
-- same result, far more efficient (O(n) instead of O(n^2)).
-- ------------------------------------------------------------
SELECT
    l.id,
    l.name,
    l.neighbourhood_group,
    l.room_type,
    l.price,
    b.borough_avg_price
FROM listings l
JOIN (
    SELECT neighbourhood_group, ROUND(AVG(price), 2) AS borough_avg_price
    FROM listings
    GROUP BY neighbourhood_group
) b ON l.neighbourhood_group = b.neighbourhood_group
WHERE l.price > b.borough_avg_price
ORDER BY l.price DESC
LIMIT 20;

-- RESULT (confirmed): Query returns correctly after refactor —
-- no timeout. Top 20 overpriced listings dominated by Manhattan
-- "Entire home/apt" (borough avg ~$178.94), but notably includes
-- a Bronx listing (avg ~$85.36) and Staten Island listing
-- (avg ~$98.58) priced at the $1,000 ceiling — extreme outliers
-- relative to their borough, flagged as high-priority price
-- review candidates.


-- ------------------------------------------------------------
-- Q3: Room type price premium by borough
-- Business question: What's the price difference between
-- Entire home/apt, Private room, and Shared room, by borough?
--
-- Technique: GROUP BY (2 dimensions), aggregation
-- ------------------------------------------------------------
SELECT
    neighbourhood_group,
    room_type,
    COUNT(*)            AS num_listings,
    ROUND(AVG(price), 2) AS avg_price,
    MIN(price)           AS min_price,
    MAX(price)           AS max_price
FROM listings
GROUP BY neighbourhood_group, room_type
ORDER BY neighbourhood_group, avg_price DESC;

-- RESULT (confirmed): Consistent pattern across all 5 boroughs —
-- Entire home/apt > Private room > Shared room. Manhattan commands
-- the highest prices in every category (Entire home/apt avg $224.75).
-- Entire-home-to-private-room price ratio is stable (~2.0-2.3x)
-- across boroughs. Shared room sample sizes are small (9-479
-- listings), especially in Staten Island (n=9) — results there
-- should be treated as low-confidence/directional only.


-- ------------------------------------------------------------
-- Q4: Top 10 hosts by estimated revenue potential
-- Business question: Which hosts generate the most estimated
-- annual revenue, using (365 - availability_365) as a proxy for
-- booked/occupied nights?
--
-- Technique: JOIN, derived calculation, aggregation, ORDER BY/LIMIT
-- NOTE: This is an ESTIMATE/PROXY — we have no actual booking or
-- transaction data. (365 - availability_365) assumes low
-- availability = high occupancy, which is a reasonable but
-- imperfect assumption (doesn't account for host deliberately
-- blocking dates, seasonal listings, etc.)
-- ------------------------------------------------------------
SELECT
    h.host_id,
    h.host_name,
    h.calculated_host_listings_count,
    COUNT(l.id) AS num_listings,
    SUM(l.price * (365 - l.availability_365)) AS estimated_annual_revenue
FROM hosts h
JOIN listings l ON h.host_id = l.host_id
GROUP BY h.host_id, h.host_name, h.calculated_host_listings_count
ORDER BY estimated_annual_revenue DESC
LIMIT 10;

-- RESULT (confirmed): Top 10 revenue hosts are dominated by
-- corporate/property-management operators (Blueground, Sonder,
-- Red Awning, The Box House Hotel, Corporate Housing, CRNY
-- Monthly Rentals) rather than individual hosts — consistent with
-- large-scale multi-unit operations.
-- NOTE: host_id 30283594 ("Kara") shows calculated_host_listings_
-- count=121 vs actual num_listings=119 in our cleaned data — minor
-- expected discrepancy, since calculated_host_listings_count is
-- sourced from the original (uncleaned) dataset and 2 of this
-- host's listings were removed as outliers during cleaning.
-- This is a known data limitation, not a bug in our schema/joins.


-- ------------------------------------------------------------
-- Q5: Underpriced listings (high demand, below-average price
-- for their borough + room type)
-- Business question: Which listings have above-average reviews
-- per month (demand signal) but below-average price relative to
-- comparable listings (same borough + room type)?
--
-- Technique: Derived table (borough+room_type average price) +
-- scalar subquery (citywide avg reviews_per_month) + JOIN
-- NOTE: Using derived-table pattern (not correlated subquery)
-- to avoid the timeout issue encountered in Q2.
-- ------------------------------------------------------------
SELECT
    l.id,
    l.name,
    l.neighbourhood_group,
    l.room_type,
    l.price,
    g.group_avg_price,
    l.reviews_per_month
FROM listings l
JOIN (
    SELECT neighbourhood_group, room_type, ROUND(AVG(price), 2) AS group_avg_price
    FROM listings
    GROUP BY neighbourhood_group, room_type
) g
    ON l.neighbourhood_group = g.neighbourhood_group
    AND l.room_type = g.room_type
WHERE l.price < g.group_avg_price
  AND l.reviews_per_month > (SELECT AVG(reviews_per_month) FROM listings WHERE reviews_per_month IS NOT NULL)
ORDER BY l.reviews_per_month DESC
LIMIT 20;

-- RESULT (confirmed): Runs instantly (derived-table pattern
-- avoided the Q2 timeout issue). Striking finding: 16/20 top
-- underpriced listings are Queens private rooms near JFK/LGA
-- airports, priced well below the $68.24 borough+room-type
-- average ($30-$67) yet showing very high demand (13-21
-- reviews/month). Strong candidate segment for host price-
-- increase recommendations — demand clearly exceeds current
-- pricing in this niche (budget airport-proximity travelers).


-- ------------------------------------------------------------
-- Q6: Overpriced listings (above-average price for borough+room
-- type, but low demand signal)
-- Business question: Which listings are priced above comparable
-- listings (same borough + room type) but show weak demand —
-- candidates for price reduction?
--
-- Technique: Derived table (borough+room_type avg price) + JOIN
-- NOTE: number_of_reviews >= 5 filter excludes brand-new listings
-- that would otherwise appear "low demand" simply due to being
-- new, not because they're genuinely overpriced.
-- ------------------------------------------------------------
SELECT
    l.id,
    l.name,
    l.neighbourhood_group,
    l.room_type,
    l.price,
    g.group_avg_price,
    l.reviews_per_month,
    l.number_of_reviews
FROM listings l
JOIN (
    SELECT neighbourhood_group, room_type, ROUND(AVG(price), 2) AS group_avg_price
    FROM listings
    GROUP BY neighbourhood_group, room_type
) g
    ON l.neighbourhood_group = g.neighbourhood_group
    AND l.room_type = g.room_type
WHERE l.price > g.group_avg_price
  AND l.number_of_reviews >= 5
  AND l.reviews_per_month < (SELECT AVG(reviews_per_month) FROM listings WHERE reviews_per_month IS NOT NULL)
ORDER BY l.price DESC
LIMIT 20;

-- RESULT (confirmed): Returns 20 high-priced ($995-$1000) listings,
-- almost entirely Manhattan "Entire home/apt" luxury properties.
-- CAVEAT: reviews_per_month is a turnover-rate metric, and luxury/
-- long-stay listings naturally have LOWER turnover (longer average
-- stays) even when genuinely in demand -- several listings here
-- have healthy total review counts (24-44), just spread over longer
-- booking cycles. This query is better interpreted as flagging
-- "low-turnover high-price listings for manual review" rather than
-- a confirmed "overpriced" diagnosis -- unlike Q5's budget-segment
-- finding, which was a cleaner demand-price mismatch signal.


-- ------------------------------------------------------------
-- Q7: High-demand, low-supply neighbourhood hotspots
-- Business question: Which neighbourhoods have above-average
-- price AND below-average availability (signals of high demand
-- relative to supply)?
--
-- Technique: GROUP BY + HAVING with subquery benchmarks
-- NOTE: Minimum listing count filter (>=10) added to avoid
-- tiny/unreliable neighbourhoods skewing results.
-- ------------------------------------------------------------
SELECT
    neighbourhood_group,
    neighbourhood,
    COUNT(*)              AS num_listings,
    ROUND(AVG(price), 2)   AS avg_price,
    ROUND(AVG(availability_365), 2) AS avg_availability
FROM listings
GROUP BY neighbourhood_group, neighbourhood
HAVING num_listings >= 10
   AND avg_price > (SELECT AVG(price) FROM listings)
   AND avg_availability < (SELECT AVG(availability_365) FROM listings)
ORDER BY avg_price DESC, avg_availability ASC
LIMIT 20;


-- RESULT (confirmed): 20 neighbourhoods returned, dominated by
-- Manhattan's most prestigious areas (NoHo $276, SoHo $254, West
-- Village $239, Greenwich Village $217). Brooklyn's 6 entries are
-- all known affluent/brownstone neighbourhoods (Cobble Hill,
-- Brooklyn Heights, Park Slope, etc.) bordering Manhattan. Result
-- strongly validates availability_365 as a credible demand proxy
-- -- the list closely mirrors real-world NYC neighbourhood
-- prestige rankings, with no unexpected/noisy entries.


-- ------------------------------------------------------------
-- Q8: Pricing behavior — above-average listing-count hosts vs
-- below-average listing-count hosts
-- Business question: Do hosts managing more listings than average
-- charge higher or lower prices than hosts managing fewer?
--
-- Technique: Subquery in WHERE (scalar benchmark) + CASE + GROUP BY
-- NOTE: Unlike Q1 (binary Power Host vs Solo Host split at >1
-- listing), this uses the actual average listing count across all
-- hosts as the threshold -- a more statistically grounded cut.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN h.calculated_host_listings_count > (SELECT AVG(calculated_host_listings_count) FROM hosts)
            THEN 'Above-Average Listing Count'
        ELSE 'Below-Average Listing Count'
    END AS host_group,
    COUNT(DISTINCT h.host_id) AS num_hosts,
    ROUND(AVG(l.price), 2)     AS avg_price,
    ROUND(AVG(h.calculated_host_listings_count), 2) AS avg_listings_per_host
FROM hosts h
JOIN listings l ON h.host_id = l.host_id
GROUP BY host_group;

-- RESULT (confirmed): Identical split to Q1 (5,148 vs 32,122 hosts,
-- same avg prices $131.13 vs $146.55). This happens because the
-- average calculated_host_listings_count across all hosts is very
-- low (pulled toward 1 by ~32,000 solo hosts), while a small number
-- of large operators (Blueground, Sonder, etc. with 200+ listings)
-- skew the mean just slightly above 1. Result: "above-average"
-- threshold and ">1 listing" threshold produce nearly the same
-- grouping here. CONCLUSION: the host-listing-count distribution
-- is heavily right-skewed; median would be a more meaningful
-- central-tendency threshold than mean for this metric, but both
-- confirm the same core finding from Q1 -- multi-listing hosts
-- price ~10% lower than solo hosts.


-- ------------------------------------------------------------
-- Q9: Top 3 most expensive listings per borough
-- Business question: What are the top 3 highest-priced listings
-- in EACH borough? (classic "Top-N per group" problem)
--
-- Technique: Window function -- ROW_NUMBER() OVER (PARTITION BY ... 
-- ORDER BY ...) -- ranks listings within each borough by price,
-- then outer query filters to rank <= 3. This is NOT possible
-- with a simple GROUP BY, since GROUP BY collapses to one row
-- per group -- we need per-row ranking within each group instead.
-- ------------------------------------------------------------
SELECT *
FROM (
    SELECT
        neighbourhood_group,
        name,
        room_type,
        price,
        ROW_NUMBER() OVER (PARTITION BY neighbourhood_group ORDER BY price DESC, id ASC) AS price_rank
    FROM listings
) ranked
WHERE price_rank <= 3
ORDER BY neighbourhood_group, price_rank;

-- RESULT (confirmed): Exactly 15 rows returned (3 per borough).
-- ROW_NUMBER() with id ASC tiebreaker produces deterministic,
-- reproducible results. NOTE: In Brooklyn, Manhattan, and Queens,
-- all 3 top-ranked listings are tied at the $1,000 price cap
-- (a cleaning-stage outlier boundary, not organic pricing) -- so
-- this query cannot distinguish TRUE top pricing in those
-- boroughs, only that they're among the capped-price listings.
-- Staten Island and Bronx show genuine price variation at the top
-- ($1,000/$800/$700 and $1,000/$800/$680 respectively), since
-- fewer listings there hit the price ceiling.


-- ------------------------------------------------------------
-- Q10: Premium power hosts (above-average price AND above-
-- average listing count)
-- Business question: Which hosts combine scale (many listings)
-- WITH premium pricing -- i.e., hosts who are both big AND
-- expensive, rather than big-but-cheap (as Q1/Q8 suggested is
-- more typical)?
--
-- Technique: Non-correlated subqueries (2 independent scalar
-- benchmarks) combined with AND
-- ------------------------------------------------------------
SELECT
    h.host_id,
    h.host_name,
    h.calculated_host_listings_count,
    ROUND(AVG(l.price), 2) AS avg_price,
    COUNT(l.id) AS num_listings
FROM hosts h
JOIN listings l ON h.host_id = l.host_id
GROUP BY h.host_id, h.host_name, h.calculated_host_listings_count
HAVING avg_price > (SELECT AVG(price) FROM listings)
   AND h.calculated_host_listings_count > (SELECT AVG(calculated_host_listings_count) FROM hosts)
ORDER BY avg_price DESC, h.calculated_host_listings_count DESC
LIMIT 20;

-- RESULT (confirmed): Returns 20 hosts combining above-average
-- listing count AND above-average price -- a distinct "premium
-- boutique" segment, contrasting with Q1/Q8's finding that
-- multi-listing hosts TYPICALLY price lower. Most hosts here have
-- modest portfolios (2-12 listings), not the 200+ listing mega-
-- operators from Q4. Red Awning appears in both Q4 (top revenue)
-- and Q10 (premium pricing) -- confirming it as a genuinely
-- high-value operator on both scale and price dimensions, unlike
-- Blueground/Sonder which are high-revenue through volume at
-- lower per-listing prices.


-- ============================================================
-- SECTION 6: EXECUTIVE SUMMARY — KEY BUSINESS FINDINGS
-- Purpose: Consolidated, readable summary of insights from the
-- 10 business questions above — intended for quick review
-- (README/GitHub/interview walkthrough) without re-reading
-- every query in full.
-- ============================================================

-- 1. HOST SEGMENTATION
--    Hosts split into two distinct economic behaviors:
--    - Volume operators (Blueground, Sonder, Corporate Housing,
--      Red Awning) manage 50-300+ listings, price ~10% LOWER on
--      average than solo hosts, and earn through scale/occupancy.
--    - Boutique premium hosts (e.g., Henry, Incentra) manage
--      modest portfolios (2-12 listings) but charge top-tier
--      prices ($650-$1,000 avg) — earning through margin, not
--      volume. Red Awning notably appears in BOTH the top-revenue
--      and top-premium-pricing lists — a rare dual-strength host.
--    - 86% of hosts are solo operators (single listing), pricing
--      on average $146.55 vs $131.13 for multi-listing hosts.

-- 2. PRICING STRUCTURE
--    - Price follows a strict, consistent hierarchy across every
--      borough: Entire home/apt > Private room > Shared room,
--      with a stable ~2.0-2.3x premium for entire homes over
--      private rooms regardless of borough.
--    - Manhattan commands the highest prices in every room-type
--      category and dominates both the "overpriced" and "top 3
--      per borough" results — often bumping against the $1,000
--      price ceiling introduced during data cleaning (a known
--      limitation: true top-end pricing in Manhattan/Brooklyn/
--      Queens can't be fully distinguished above the cap).

-- 3. DEMAND VS PRICE MISMATCHES (core finding for this project's
--    "Dynamic Price Recommendation" framing)
--    - UNDERPRICED SEGMENT: Queens private rooms near JFK/LGA
--      airports show the strongest demand-price mismatch —
--      priced well below the borough+room-type average ($30-$67
--      vs $68.24 avg) yet showing very high demand (13-21
--      reviews/month). Strong candidates for price increases.
--    - OVERPRICED SEGMENT: Manhattan luxury listings priced at
--      $995-$1,000 show low reviews-per-month, but this requires
--      nuance — luxury/long-stay listings naturally turn over
--      more slowly, so low review velocity doesn't necessarily
--      mean low demand. Flagged for manual review, not a
--      confirmed "lower your price" recommendation.

-- 4. GEOGRAPHIC HOTSPOTS
--    - High-price + low-availability neighbourhoods align almost
--      perfectly with NYC's real-world prestige map: NoHo, SoHo,
--      West Village, Greenwich Village (Manhattan), and Cobble
--      Hill, Brooklyn Heights, Park Slope (Brooklyn). This
--      validates availability_365 as a credible demand proxy.

-- 5. DATA PIPELINE AWARENESS
--    - A correlated subquery approach (Q2) caused a connection
--      timeout at 48,631 rows and was refactored into a derived-
--      table/JOIN pattern — a deliberate performance optimization
--      reused in Q5 and Q6.
--    - RANK() vs ROW_NUMBER() distinction mattered in Q9: RANK()
--      correctly returns all ties, but ROW_NUMBER() was needed
--      for a clean "exactly top 3 per group" business answer.
--    - The $1,000 price cap from the data cleaning stage surfaces
--      again here as an analysis limitation — a good example of
--      end-to-end pipeline awareness (a decision made early
--      affects what's answerable later).

-- OVERALL CONCLUSION:
-- The data supports a genuine "dynamic pricing" opportunity —
-- specific, identifiable listings (e.g., Queens airport-proximity
-- rooms) are measurably underpriced relative to demand, while
-- other segments require more nuanced, non-mechanical judgment
-- (e.g., Manhattan luxury listings). This directly motivates the
-- next pipeline stage: a machine learning model that can predict
-- a data-driven "fair price" per listing, replacing manual rules
-- like the ones used in this SQL analysis.
-- ============================================================