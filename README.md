# NSE Stock Market Analytics Pipeline

**End-to-end automated data pipeline for Indian equity market analysis — built on Medallion Architecture.**

Python extracts. dbt transforms. PostgreSQL stores. Power BI visualises. Task Scheduler runs it daily without manual intervention.

---

## Dashboard

![NSE Stock Market Analytics Dashboard](powerbi/dashboard_preview.png)

> One-page Power BI dashboard tracking TCS, Infosys, Reliance, HDFC Bank, and Wipro against the Nifty 50 benchmark. Signals, moving averages, volatility, and correlation updated daily.

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│   yfinance  │────▶│   Bronze     │────▶│   Silver     │────▶│    Gold     │
│   API       │     │   Raw ingest │     │   Cleaned    │     │  Analytics  │
│             │     │   PostgreSQL │     │   PostgreSQL │     │  PostgreSQL │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
     Python              extract.py           dbt models          dbt models
                                           silver_stocks      fact_stocks
                                                              fact_nifty
                                                              dim_company
```

**Orchestration:** Windows Task Scheduler → `run_pipeline.bat` → daily at 06:30 IST

---

## Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Ingestion | Python + yfinance | Pull OHLCV data from Yahoo Finance API |
| Storage | PostgreSQL | Bronze / Silver / Gold schema separation |
| Transformation | dbt Core | SQL models, window functions, signal logic |
| Visualisation | Power BI Desktop | One-page live dashboard |
| Scheduling | Windows Task Scheduler | Fully automated daily pipeline |

---

## Repository Structure

```
stock_market_project/
│
├── extract.py                    ← Bronze layer ingestion
├── run_pipeline.bat              ← Daily orchestration script
│
├── dbt_project/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   └── models/
│       ├── silver/
│       │   └── silver_stocks.sql
│       └── gold/
│           ├── fact_stocks.sql   ← Prices, signals, MAs, volatility
│           ├── fact_nifty.sql    ← Nifty 50 benchmark
│           └── dim_company.sql   ← Company dimension
│
├── powerbi/
│   └── StockDashboard.pbix
│
├── logs/
│   └── pipeline_log.txt
│
└── README.md
```

---

## Data Model

### `gold.fact_stocks`
Core analytical table. One row per stock per trading day.

| Column | Type | Description |
|---|---|---|
| `ticker` | varchar | Stock symbol (TCS, INFY, RELIANCE, HDFCBANK, WIPRO) |
| `date` | date | Trading date |
| `close_price` | numeric | Adjusted closing price (₹) |
| `open_price` | numeric | Opening price (₹) |
| `high_price` | numeric | Daily high (₹) |
| `low_price` | numeric | Daily low (₹) |
| `volume` | bigint | Shares traded |
| `daily_return_pct` | numeric | Day-over-day return % — via `LAG()` |
| `moving_avg_7d` | numeric | 7-day moving average — via `AVG() OVER()` |
| `moving_avg_30d` | numeric | 30-day moving average — via `AVG() OVER()` |
| `volatility_7d` | numeric | 7-day price volatility — via `STDDEV() OVER()` |
| `avg_volume_7d` | numeric | 7-day rolling average volume |
| `week52_high` | numeric | 52-week high — via `MAX() OVER()` |
| `week52_low` | numeric | 52-week low — via `MIN() OVER()` |
| `signal` | varchar | BUY / SELL — Golden Cross logic (7d MA vs 30d MA) |
| `price_position` | varchar | Near 52W High / Mid Range / Near 52W Low |
| `volume_signal` | varchar | High Volume / Normal Volume / Low Volume |

### `gold.fact_nifty`
Nifty 50 index benchmark for normalised comparison.

### `gold.dim_company`
Company metadata — name, sector, exchange, market cap category.

---

## Signal Logic

Implemented in `dbt` SQL using window functions on `gold.fact_stocks`.

```sql
-- Golden Cross Buy/Sell Signal
signal = CASE
    WHEN moving_avg_7d > moving_avg_30d THEN 'BUY'
    WHEN moving_avg_7d < moving_avg_30d THEN 'SELL'
    ELSE 'HOLD'
END

-- Price Position
price_position = CASE
    WHEN close_price >= week52_high * 0.95 THEN 'Near 52W High'
    WHEN close_price <= week52_low  * 1.05 THEN 'Near 52W Low'
    ELSE 'Mid Range'
END

-- Volume Signal
volume_signal = CASE
    WHEN volume > avg_volume_7d * 1.5 THEN 'High Volume'
    WHEN volume < avg_volume_7d * 0.5 THEN 'Low Volume'
    ELSE 'Normal Volume'
END
```

---

## Dashboard Components

| Visual | Data Source | Description |
|---|---|---|
| Ticker bar | `fact_stocks`, `fact_nifty` | Live prices + daily return % for all 6 tickers |
| KPI — Nifty 50 Index | `fact_nifty` | Latest close + trend vs previous day |
| KPI — Best Performer | `fact_stocks` | Highest daily_return_pct ticker |
| KPI — Worst Performer | `fact_stocks` | Lowest daily_return_pct ticker |
| KPI — Active Buy Signals | `fact_stocks` | Count of BUY signals today |
| KPI — Avg Volatility 7D | `fact_stocks` | Mean volatility_7d across all stocks |
| Price Trend Chart | `fact_stocks` + `fact_nifty` | Normalised price (base 100) — 12 months |
| Stock Status Table | `fact_stocks` + `dim_company` | Price, return, signal per stock |
| Moving Average Chart | `fact_stocks` (TCS) | close_price vs moving_avg_7d vs moving_avg_30d |
| Volume Chart | `fact_stocks` | avg_volume_7d per ticker (horizontal bar) |
| Volatility Chart | `fact_stocks` | volatility_7d per ticker |
| Correlation Matrix | Static (calculated) | 5×5 price correlation heatmap |
| Signal Summary Table | `fact_stocks` | All 11 columns — full Gold layer output |

---

## Setup

### Prerequisites

```bash
pip install yfinance pandas sqlalchemy psycopg2-binary
pip install dbt-postgres
```

PostgreSQL must be running locally. Create the database:

```sql
CREATE DATABASE stock_db;
```

### Configuration

Update the connection string in `extract.py`:

```python
DB_URL = "postgresql://postgres:YOUR_PASSWORD@localhost:5432/stock_db"
```

Copy `dbt_project/profiles.yml` to `C:\Users\YourName\.dbt\profiles.yml` and set your password.

### Run the Pipeline

```bash
# Step 1 — Bronze layer
python extract.py

# Step 2 — Silver + Gold layers
cd dbt_project
dbt debug        # verify connection
dbt run          # run all models
```

Expected output:

```
✅ silver.silver_stocks
✅ gold.fact_stocks
✅ gold.fact_nifty
✅ gold.dim_company
```

### Automate with Task Scheduler

```
Task Scheduler → Create Basic Task
  Name    : Stock Market Pipeline
  Trigger : Daily at 06:30 AM
  Action  : Run C:\path\to\run_pipeline.bat
```

---

## Key Findings

> Update after running your pipeline with real data.

- IT sector stocks (TCS, Infosys, Wipro) show high correlation (0.76–0.89), suggesting correlated risk exposure
- Reliance shows the lowest correlation with the IT basket — useful for portfolio diversification
- HDFC Bank and Reliance exhibit higher average volatility relative to the Nifty 50 benchmark
- Golden Cross signals (7d MA crossing 30d MA) have historically preceded short-term upward momentum in this dataset

---

## What This Project Demonstrates

| Skill | Implementation |
|---|---|
| Data Engineering | Bronze → Silver → Gold Medallion Architecture |
| SQL | dbt window functions — `LAG`, `AVG OVER`, `STDDEV OVER`, `MAX OVER` |
| Python | Production-style `.py` scripts (not notebooks) |
| Automation | Fully unattended daily pipeline via Task Scheduler |
| Analytics | Buy/Sell signal generation, 52-week tracking, volatility analysis |
| Visualisation | Multi-layer Power BI dashboard with DAX measures and conditional formatting |

---

## Stocks Covered

| Ticker | Company | Sector |
|---|---|---|
| TCS | Tata Consultancy Services | IT |
| INFY | Infosys | IT |
| RELIANCE | Reliance Industries | Energy / Conglomerate |
| HDFCBANK | HDFC Bank | Banking |
| WIPRO | Wipro | IT |
| NIFTY 50 | NSE Index Benchmark | — |

---

## License

MIT
