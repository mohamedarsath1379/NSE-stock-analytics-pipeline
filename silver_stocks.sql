
-- ============================================================
-- FILE: models/silver/silver_stocks.sql
-- PURPOSE: Clean bronze data → Silver layer
-- ============================================================

{{
    config(
        materialized='table',
        schema='silver'
    )
}}

WITH ranked_data AS (

    SELECT
        date,

        -- Clean ticker (remove .NS suffix)
        CASE
            WHEN ticker = '^NSEI' THEN 'NIFTY50'
            ELSE REPLACE(ticker, '.NS', '')
        END AS ticker,

        company_name,

        -- Round prices
        ROUND(CAST(open_price  AS NUMERIC), 2) AS open_price,
        ROUND(CAST(high_price  AS NUMERIC), 2) AS high_price,
        ROUND(CAST(low_price   AS NUMERIC), 2) AS low_price,
        ROUND(CAST(close_price AS NUMERIC), 2) AS close_price,

        volume,
        loaded_at,

        -- Remove duplicates
        ROW_NUMBER() OVER (
            PARTITION BY date, ticker
            ORDER BY loaded_at DESC
        ) AS rn

    FROM bronze_stocks

    -- Remove bad records
    WHERE close_price IS NOT NULL
      AND date IS NOT NULL
      AND open_price > 0

)

SELECT
    date,
    ticker,
    company_name,
    open_price,
    high_price,
    low_price,
    close_price,
    volume,
    loaded_at

FROM ranked_data

WHERE rn = 1