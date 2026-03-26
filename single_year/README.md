# Single-Year SPM Adequacy Ratio Computation

This folder contains a **self-contained script** that computes the 20th, 50th, and 80th percentile of the SPM adequacy ratio for one year of Census data. It has no dependencies on any other file in this repository.

The script is designed to be readable: seven clearly labeled steps, plain comments, ~30 lines of active code. If you want to understand or manually verify the methodology, start here.

---

## What it produces

```
SPM family units in file:  58,147

SPM adequacy ratio at selected percentiles
(1.00 = exactly at the family's poverty threshold)

  20th percentile: 1.1628
  50th percentile: 2.3442
  80th percentile: 4.3312
```

(Above is the 2024 income year result.)

---

## How to use it

### Step 1: Get the data

Download a CPS ASEC person file from Census. See [`data/README.md`](data/README.md) for the direct download links and file naming guide.

Place the extracted CSV in the `data/` subfolder of this folder.

### Step 2: Set the filename

Open `single_year.R` and update the `FILE_PATH` variable at the top to match the file you downloaded:

```r
FILE_PATH <- "data/pppub25.csv"   # change pppub25.csv to your filename
```

### Step 3: Install the one required package (if needed)

```r
install.packages("data.table")
```

### Step 4: Run the script

From this folder:

```bash
Rscript single_year.R
```

Or open it in RStudio and run it top to bottom.

---

## What the adequacy ratio means

`adequacy = SPM_Resources / SPM_PovThreshold`

- **SPM_Resources** is comprehensive: cash income + food/housing/energy benefits + refundable tax credits − federal/state/FICA taxes − work and childcare expenses − medical out-of-pocket costs.
- **SPM_PovThreshold** is family-specific: it adjusts for family size and local housing costs, so a ratio of 1.0 means the same thing regardless of where the family lives or how big it is.
- **Ratio > 1**: above the poverty line
- **Ratio = 1**: exactly at the poverty line
- **Ratio < 1**: below the poverty line (in SPM poverty)

Families are ranked by this ratio, so the 20th percentile is the family at the bottom fifth of the well-being distribution — the point where 20% of all US families have lower adequacy.

---

## Requirements

- R (any recent version)
- Package: `data.table`
- One CPS ASEC person-level CSV from Census (see `data/README.md`)

No internet connection required once the data file is downloaded.
