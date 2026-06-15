-- ============================================================
-- FILE: models/gold/dim_company.sql
-- PURPOSE: Dimension table for companies
-- ============================================================

{{
    config(
        materialized='table',
        schema='gold'
    )
}}

SELECT DISTINCT
    ticker,
    company_name,

    -- Sector classification
    CASE ticker
        WHEN 'TCS'      THEN 'Information Technology'
        WHEN 'INFY'     THEN 'Information Technology'
        WHEN 'WIPRO'    THEN 'Information Technology'
        WHEN 'RELIANCE' THEN 'Energy & Retail'
        WHEN 'HDFCBANK' THEN 'Banking & Finance'
    END                 AS sector,

    -- Market classification
    CASE ticker
        WHEN 'TCS'      THEN 'Large Cap'
        WHEN 'INFY'     THEN 'Large Cap'
        WHEN 'WIPRO'    THEN 'Large Cap'
        WHEN 'RELIANCE' THEN 'Large Cap'
        WHEN 'HDFCBANK' THEN 'Large Cap'
    END                 AS market_cap_category,

    -- Exchange
    'NSE'               AS exchange,
    'India'             AS country

FROM {{ ref('silver_stocks') }}
WHERE ticker != 'NIFTY50'
