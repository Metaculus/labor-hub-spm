# Data Download Instructions

Place your downloaded CSV file in this folder, then update `FILE_PATH` in `single_year.R` to match the filename.

---

## Where to get the data

CPS ASEC files are free public downloads from the Census Bureau. No account or registration required.

**Base URL:**
```
https://www2.census.gov/programs-surveys/cps/datasets/[SURVEY_YEAR]/march/
```

---

## File naming guide

The survey year is one year after the income year (the survey asks about last year's income).

| Income year | Survey year | Zip file to download | CSV inside zip |
|---|---|---|---|
| 2018 | 2019 | `asecpub19csv.zip` | `pppub19.csv` |
| 2019 | 2020 | `asecpub20csv.zip` | `pppub20.csv` |
| 2020 | 2021 | `asecpub21csv.zip` | `pppub21.csv` |
| 2021 | 2022 | `asecpub22csv.zip` | `pppub22.csv` |
| 2022 | 2023 | `asecpub23csv.zip` | `pppub23.csv` |
| 2023 | 2024 | `asecpub24csv.zip` | `pppub24.csv` |
| 2024 | 2025 | `asecpub25csv.zip` | `pppub25.csv` |

---

## Direct download links

Click to download the zip, then extract the `pppubYY.csv` file into this folder.

- **2024** (most recent): https://www2.census.gov/programs-surveys/cps/datasets/2025/march/asecpub25csv.zip
- **2023**: https://www2.census.gov/programs-surveys/cps/datasets/2024/march/asecpub24csv.zip
- **2022**: https://www2.census.gov/programs-surveys/cps/datasets/2023/march/asecpub23csv.zip
- **2021**: https://www2.census.gov/programs-surveys/cps/datasets/2022/march/asecpub22csv.zip
- **2020**: https://www2.census.gov/programs-surveys/cps/datasets/2021/march/asecpub21csv.zip
- **2019**: https://www2.census.gov/programs-surveys/cps/datasets/2020/march/asecpub20csv.zip
- **2018**: https://www2.census.gov/programs-surveys/cps/datasets/2019/march/asecpub19csv.zip

Files are ~150–200 MB compressed. The extracted CSV is ~300–400 MB.

> **Note for 2018 (survey year 2019):** The zip has an unusual internal folder structure. Extract the full zip and look for `pppub19.csv` inside the `cpspb/asec/prod/data/2019/` subfolder.

---

## What columns the script uses

The script reads only four columns from the file:

| Column | What it is |
|---|---|
| `SPM_HEAD` | 1 = reference person of the SPM family unit (one per family) |
| `SPM_WEIGHT` | Survey weight (stored ×100; the script handles this automatically) |
| `SPM_RESOURCES` | Total SPM resources in dollars (post-tax, post-transfer, post-expense) |
| `SPM_POVTHRESHOLD` | The family's SPM poverty threshold in dollars (varies by size and location) |

All other columns in the file are ignored.
