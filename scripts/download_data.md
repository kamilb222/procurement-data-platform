# Downloading the dataset

This project uses the **California State Purchase Order Data** (SCPRS extract,
fiscal years 2012-2015).

- **Primary source:** https://data.ca.gov/dataset/purchase-order-data
- **Mirror:** Kaggle — "Large Purchases by the State of CA"
  (https://www.kaggle.com/datasets/sohier/large-purchases-by-the-state-of-ca)

## Steps

1. Download the CSV export from either source above.
2. Place it at:

   ```
   data/raw/purchase_orders.csv
   ```

3. Verify the row count (logical CSV rows, not raw line count — some text
   fields contain embedded newlines, see note below):

   ```bash
   python -c "import pandas as pd; print(len(pd.read_csv('data/raw/purchase_orders.csv', dtype=str)))"
   ```

   Expected: **344,504 rows** (fiscal years 2012-2015). If your download has a
   noticeably different count, note it — the source dataset is updated
   periodically and vintages can drift.

`data/raw/` and `data/processed/` are gitignored — nothing here is ever
committed. If you need sample data for tests, use the synthetic fixtures in
`tests/fixtures/` instead.

**Note on row count:** `wc -l data/raw/purchase_orders.csv` reports far more
lines than actual rows. The `Location` column stores multi-line values (a zip
code followed by a `(lat, lon)` pair on a second physical line, inside quotes),
which is valid CSV but throws off naive line counting. Always parse with a
real CSV reader (pandas, in this project) rather than counting lines.
