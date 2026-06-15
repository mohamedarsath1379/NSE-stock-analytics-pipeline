```bat id="0z4w5n"
@echo off

cd /d "D:\data analyst\stock market analaysis"

call venv\Scripts\activate.bat

python extract.py

cd dbt_project

dbt run

pause
```
