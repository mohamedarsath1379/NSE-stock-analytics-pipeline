-- ============================================================
-- FILE: models/gold/fact_nifty.sql
-- PURPOSE: Nifty50 index data for benchmark comparison
-- ============================================================

{{
    config(
        materialized='table',
        schema='gold'
    )
}}

SELECT
    date,
    ticker,
    close_price,

    -- Daily return
    ROUND(
        (close_price - LAG(close_price) OVER (
            ORDER BY date
        )) /
        NULLIF(LAG(close_price) OVER (
            ORDER BY date
        ), 0) * 100
    , 2)                AS daily_return_pct,

    -- 30 day moving average
    ROUND(AVG(close_price) OVER (
        ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2)               AS moving_avg_30d

FROM {{ ref('silver_stocks') }}
WHERE ticker = 'NIFTY50'
ORDER BY date
