-- ============================================================
-- FILE: models/gold/fact_stocks.sql
-- PURPOSE: All calculations → Gold layer
-- This is where SQL does the REAL work (not Python)
-- Window Functions, LAG, Moving Averages, Signals
-- ============================================================

{{
    config(
        materialized='table',
        schema='gold'
    )
}}

WITH base AS (
    SELECT * FROM {{ ref('silver_stocks') }}
    WHERE ticker != 'NIFTY50'   -- stocks only, index separate
),

calculations AS (
    SELECT
        date,
        ticker,
        company_name,
        open_price,
        high_price,
        low_price,
        close_price,
        volume,

        --  DAILY RETURN %
        ROUND(
            (close_price - LAG(close_price) OVER (
                PARTITION BY ticker
                ORDER BY date
            )) /
            NULLIF(LAG(close_price) OVER (
                PARTITION BY ticker
                ORDER BY date
            ), 0) * 100
        , 2)                                AS daily_return_pct,

        -- 7 DAY MOVING AVERAGE
        ROUND(AVG(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2)                               AS moving_avg_7d,

        -- 30 DAY MOVING AVERAGE
        ROUND(AVG(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ), 2)                               AS moving_avg_30d,

        -- VOLATILITY (7 day rolling std dev)
        ROUND(STDDEV(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2)                               AS volatility_7d,

        -- 52 WEEK HIGH
        MAX(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 251 PRECEDING AND CURRENT ROW
        )                                   AS week52_high,

        -- 52 WEEK LOW
        MIN(close_price) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 251 PRECEDING AND CURRENT ROW
        )                                   AS week52_low,

        -- VOLUME 7 DAY AVERAGE
        ROUND(AVG(volume) OVER (
            PARTITION BY ticker
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 0)                               AS avg_volume_7d

    FROM base
),

signals AS (
    SELECT
        *,

        -- BUY / SELL SIGNAL
        -- Golden Cross: 7d MA crosses above 30d MA = BUY
        -- Death Cross:  7d MA crosses below 30d MA = SELL
        CASE
            WHEN moving_avg_7d > moving_avg_30d THEN 'BUY'
            WHEN moving_avg_7d < moving_avg_30d THEN 'SELL'
            ELSE 'HOLD'
        END                                 AS signal,

        -- PRICE POSITION
        -- Where is price relative to 52 week range?
        CASE
            WHEN close_price >= week52_high * 0.95 THEN 'Near 52W High'
            WHEN close_price <= week52_low  * 1.05 THEN 'Near 52W Low'
            ELSE 'Mid Range'
        END                                 AS price_position,

        --  VOLUME SIGNAL
        CASE
            WHEN volume > avg_volume_7d * 1.5 THEN 'High Volume'
            WHEN volume < avg_volume_7d * 0.5 THEN 'Low Volume'
            ELSE 'Normal Volume'
        END                                 AS volume_signal

    FROM calculations
)

SELECT * FROM signals
ORDER BY ticker, date
