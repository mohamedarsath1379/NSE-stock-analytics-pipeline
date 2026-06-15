# ============================================================
# STOCK MARKET ANALYTICS
# FILE: extract.py
# PURPOSE: Pull NSE stock data → store in PostgreSQL Bronze
# RUN: python extract.py
# ============================================================
import yfinance as yf
import pandas as pd
from sqlalchemy import create_engine, text
import logging
from datetime import datetime
# ── LOGGING ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)
logger=logging.getLogger(__name__)

# ── DATABASE CONNECTION ───────────────────────────────────
# Change username, password, dbname to your PostgreSQL details
DB_URL = "postgresql://postgres:postgres123@localhost:5432/stock_db"
engine = create_engine(DB_URL)

# ── STOCKS TO TRACK ───────────────────────────────────────
STOCKS = {
    'TCS.NS'       : 'TCS',
    'INFY.NS'      : 'Infosys',
    'RELIANCE.NS'  : 'Reliance',
    'HDFCBANK.NS'  : 'HDFC Bank',
    'WIPRO.NS'     : 'Wipro',
    '^NSEI'        : 'Nifty50'
}

# ── CREATE BRONZE TABLE ───────────────────────────────────
def create_bronze_table():
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS bronze_stocks (
                id              SERIAL PRIMARY KEY,
                date            DATE,
                ticker          VARCHAR(20),
                company_name    VARCHAR(50),
                open_price      FLOAT,
                high_price      FLOAT,
                low_price       FLOAT,
                close_price     FLOAT,
                volume          BIGINT,
                loaded_at       TIMESTAMP DEFAULT NOW()
            )
        """))
        conn.commit()
    logger.info("Bronze table ready")

# ── EXTRACT AND LOAD ──────────────────────────────────────
def extract_and_load():
    create_bronze_table()

    for ticker, company in STOCKS.items():
        try:
            logger.info(f"Pulling {company} ({ticker})...")

            # Pull 2 years historical data
            df = yf.download(
                ticker,
                period='2y',
                auto_adjust=True,
                progress=False
            )

            if df.empty:
                logger.warning(f"No data for {ticker}")
                continue

            # Clean column names
            df = df.reset_index()
            df.columns = [
                'date', 'close_price', 'high_price',
                'low_price', 'open_price', 'volume'
            ]

            # Add metadata
            df['ticker']       = ticker
            df['company_name'] = company
            df['loaded_at']    = datetime.now()

            # Remove duplicates before loading
            with engine.connect() as conn:
                conn.execute(text(f"""
                    DELETE FROM bronze_stocks
                    WHERE ticker = '{ticker}'
                """))
                conn.commit()

            # Load to PostgreSQL
            df[[
                'date', 'ticker', 'company_name',
                'open_price', 'high_price', 'low_price',
                'close_price', 'volume', 'loaded_at'
            ]].to_sql(
                'bronze_stocks',
                engine,
                if_exists='append',
                index=False
            )

            logger.info(f"{company}: {len(df)} rows loaded")

        except Exception as e:
            logger.error(f" Error loading {ticker}: {e}")

    logger.info(" Bronze layer complete!")

# ── RUN ───────────────────────────────────────────────────
if __name__ == "__main__":
    extract_and_load()

