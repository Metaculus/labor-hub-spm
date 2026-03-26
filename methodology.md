# SPM Adequacy Ratio: Methodology, Reflections, and Caveats

## Summary

- **Data:** Census CPS ASEC public-use person file, income years 2018–2024, downloaded directly from Census.gov
- **Unit of analysis:** SPM family unit — one row per unit, obtained by filtering to `SPM_HEAD == 1`
- **Key variable:** Adequacy ratio = `SPM_Resources / SPM_PovThreshold`
  - `SPM_Resources`: post-tax, post-transfer, post-expense comprehensive family resources (cash income + in-kind benefits + refundable tax credits − taxes − work/childcare expenses − medical out-of-pocket)
  - `SPM_PovThreshold`: BLS-derived poverty threshold, pre-adjusted for family size and local housing costs; provided directly in the data file
- **Ranking:** All units sorted ascending by adequacy ratio (worst-off to best-off)
- **Weighting:** `SPM_Weight` used as unit weight throughout (stored ×100 in raw files; divided internally before summing)
- **Output:** Exact weighted 20th, 50th, and 80th percentile of the adequacy distribution — three values per year, 2018–2024
- **Interpretation:** Ratio of 1.0 = resources exactly equal the unit's poverty threshold; ratio of 2.0 = twice the resources needed; below 1.0 = in SPM poverty

A full overview of methodology, data sources, limitations, and forward-looking considerations follows below.

---

## 1. Core Methodology

### Data source

**CPS ASEC (income years 2018–2024):** Main CPS ASEC person file CSV zips from the Census CPS datasets page. These are **CPS ASEC-based** (~58,000–72,000 SPM family units per year). SPM variables are embedded directly in the main person file.

**Income reference period:** CPS ASEC asks about income in the **prior calendar year**, so the survey conducted in March 2025 covers income year 2024.

**Most recent data:** 2025 CPS ASEC covering income year 2024 (released September 2025).

---

### Step 1: Collapse to SPM unit level

Filter to `SPM_HEAD == 1`. SPM variables are stored on every person record in the file; keeping only the reference person (head) gives one row per SPM family unit.

Use `SPM_Weight` as the unit weight throughout. Weights are stored ×100 in the raw file (a Census convention); coerce to numeric and divide by 100 where needed for population counts.

---

### Step 2: Compute the adequacy ratio

```
adequacy = SPM_Resources / SPM_PovThreshold
```

This is both the **ranking variable** and the **outcome variable**. Units are sorted by their adequacy ratio, and the reported metric at each percentile is that unit's adequacy ratio.

**`SPM_Resources`** is total SPM resources: cash income + SNAP, WIC, school lunch, housing subsidies, energy assistance, broadband subsidies (from 2021) + refundable tax credits (EITC, ACTC) − federal/state/FICA taxes − capped work and childcare expenses − medical out-of-pocket expenses and health insurance premiums.

**`SPM_PovThreshold`** is the unit-specific poverty threshold. It is pre-computed by BLS and provided in the data file. It varies by family size and composition (via `SPM_EquivScale`) and by local housing costs (via `SPM_GeoAdj`). It adjusts for both dimensions of need simultaneously, making the adequacy ratio comparable across family types and geographies.

An adequacy ratio of 1.0 means resources exactly equal the unit's poverty threshold. Values above 1.0 indicate resources exceed the threshold by that multiple; below 1.0 indicates SPM poverty.

**Why use adequacy for both ranking and outcome:** Ranking by the adequacy ratio places units in order of their actual need-adjusted well-being, accounting for both family size *and* geographic cost variation. The P20 adequacy ratio then directly answers: "What is the level of need-adjusted resources for the unit at the 20th percentile of the well-being distribution?" This is more internally consistent than ranking by a pre-expense income variable (which ignores expense burden variation) or by equivalized resources alone (which ignores geographic cost variation embedded in the threshold).

Drop records with `SPM_PovThreshold <= 0` before computing.

---

### Step 3: Exact weighted percentiles

Sort units by `adequacy` (ascending). Compute the weighted cumulative distribution using `SPM_Weight` (coerced to numeric/double before `cumsum()` to avoid 32-bit integer overflow — total weights sum to ~13B for CPS ASEC files).

For each target percentile p ∈ {0.20, 0.50, 0.80}, the reported value is the first `adequacy` value where the cumulative weight meets or exceeds `p × total_weight` (standard type-1 weighted quantile / lower).

No percentile bands are used. With ~60,000 SPM units, exact weighted percentiles at P20/P50/P80 are stable.

---

## 2. SPM Threshold Construction

The SPM poverty threshold is produced by the Bureau of Labor Statistics (BLS) and provided pre-computed in the data as `SPM_PovThreshold`. Researchers do not need to construct it.

**Construction:** BLS derives the reference threshold from Consumer Expenditure Survey (CE) spending on food, clothing, shelter, and utilities (FCSU) by consumer units with children, at roughly the 30th–36th percentile of FCSU spending, multiplied by 1.2 (the "little else" multiplier). The threshold is then adjusted for family composition via `SPM_EquivScale` and for local housing costs via `SPM_GeoAdj`.

**Rolling average window:** Since the 2020 threshold (released September 2021), BLS uses **5 years of quarterly CE data** (20 quarters). Prior to 2020 thresholds, BLS used a **3-year window** — this creates a discontinuity in the threshold's lag characteristics around income years 2019–2020.

**Effective lag:** The 5-year CE window means the threshold reflects spending patterns approximately 2–4 years prior to the income year. The 3-year pre-2020 window had a shorter lag (~1.5–2.5 years).

---

## 3. Reflections on the Measure's Strengths

**Internally consistent well-being measure.** Both the ranking variable and the outcome are `SPM_Resources / SPM_PovThreshold`. The P20 unit is the unit at the 20th percentile of need-adjusted final resources — the 20th worst-off household in America by the most comprehensive available measure. This is cleaner and more interpretable than approaches that rank by one variable and measure by another.

**Adjusts for family size and geography simultaneously.** `SPM_PovThreshold` encodes both `SPM_EquivScale` (family composition) and `SPM_GeoAdj` (local housing costs). A family in San Francisco and a same-size family in rural Mississippi are ranked by how well they meet their own local cost of living. Ranking by equivalized resources alone (SPM_Resources / SPM_EquivScale) would miss the geographic dimension.

**Comprehensive resource concept.** SPM_Resources is significantly more comprehensive than census money income — it captures EITC, SNAP, housing subsidies, and subtracts taxes, medical costs, and work expenses. The adequacy ratio captures the full effect of taxes and transfers.

**Captures deflation in necessities.** If AI-driven productivity growth makes food, clothing, or utilities substantially cheaper, the threshold will eventually fall (via the CE rolling average), and the adequacy ratio will correctly reflect the improvement.

**Principled and interpretable across time.** A ratio of 1.0 consistently means "resources equal to what a similarly-sized family at the lower end of the spending distribution actually spends on FCSU today" — a stable, grounded anchor.

---

## 4. Gaps, Limitations, and Caveats

### 4.1 Underreporting of income and transfers

CPS ASEC underreports government transfer income relative to administrative records. SNAP receipt is captured at roughly 60–75% of administrative totals. SPM_Resources systematically understates actual resources for lower-income units; P20 adequacy ratios are likely biased downward.

### 4.2 FCSU basket scope and AI-era necessities

The threshold covers only Food, Clothing, Shelter, and Utilities × 1.2. Healthcare, transportation, internet/broadband, digital services, and education are not in the basket. If AI services or digital participation become genuine economic necessities by 2030–2035, they will not enter the threshold. The adequacy ratio could overstate true adequacy in a world where non-FCSU necessities have substantially expanded. This is the primary structural limitation for long-horizon forecasting.

### 4.3 Threshold lag

The 5-year CE rolling average (post-2020) creates an effective lag of ~2–4 years. During periods of rapidly rising FCSU costs, the threshold understates current minimum needs. The 3-year pre-2020 window had a shorter lag (~1.5–2.5 years). This creates a structural break in lag characteristics around 2019–2020.

### 4.4 Medical expenses

SPM subtracts medical out-of-pocket expenses from resources. The adequacy ratio falls when a unit faces higher medical costs even if care is covered by insurance. Policy changes affecting coverage (ACA, Medicare drug pricing) show up as adequacy changes that are not purely income-driven.

### 4.5 Housing cost measurement

The geographic adjustment is at the metro-area level and does not capture within-metro variation or rapid housing escalation in high-cost cities.

### 4.6 Cross-sectional, not longitudinal

CPS ASEC is cross-sectional. The percentile adequacy ratios reflect the current composition of units at each position, not the trajectory of the same units over time. If AI displaces middle-skill workers who slide down the distribution, the P50 ratio may remain stable even as displaced workers are now worse off.

### 4.7 SPM methodology changes over time

The series has undergone structural changes: broadband subsidies added in 2021 (CPS ASEC SPM only), MOOP imputation changes, the 3→5 year CE window change in 2020 thresholds, and the 2014 CPS ASEC questionnaire redesign affecting high-income respondents. All are annotated in the output.

### 4.8 AI impact attribution

The ratio will move with productivity growth, policy changes, inflation, demographic shifts, and sector-specific labor market changes. Isolating the AI effect from these confounders is not possible from this measure alone.

---

## 5. Historical Reach and Structural Breaks

**Active series: income years 2018–2024** (7 years).

| Income year(s) | Note |
|---|---|
| 2020 | COVID field limitations (telephone-only interviews) |
| 2021 | ARPA policy spike (expanded CTC, stimulus, enhanced UI) |

**Pre-2018:** CPS ASEC files with embedded SPM variables are not publicly available before the 2019 survey (income year 2018). See the appendix below for notes on the ACS-based extension to 2010–2017.

**Pre-2010:** The SPM was not published before the 2011 CPS ASEC. The Wimer et al. historical SPM series provides pre-2010 estimates using a different methodology; do not concatenate without explicit bridging.

---

## 6. Forward-Looking Considerations (2030 and 2035)

**What would move the ratios?**

- *P20:* Transfer program generosity (SNAP, EITC, housing subsidies) and low-wage labor market conditions. AI displacement of low-skill service work could depress this ratio; expanded transfers could offset it.
- *P50:* Median wage growth, middle-class tax policy, healthcare costs. Routine cognitive task automation would show up here first.
- *P80:* High-skill wage growth and capital income. Likely to benefit from AI productivity gains before facing displacement risk.

**Key forecasting caveats:**

1. Policy is endogenous — government transfers partially offset labor market shocks.
2. The threshold rises with real consumption growth — maintaining the ratio requires resource growth above FCSU inflation.
3. FCSU basket scope limitations become more binding at longer horizons if AI changes the nature of minimum necessities.
4. The 2021 ARPA spike makes it a poor baseline.

---

## 7. Official Sources

| Resource | URL |
|---|---|
| CPS ASEC datasets index | https://www.census.gov/data/datasets/time-series/demo/cps/cps-asec.html |
| SPM datasets (pre-2019 extracts) | https://www.census.gov/topics/income-poverty/supplemental-poverty-measure/data/datasets.html |
| SPM technical documentation | https://www2.census.gov/programs-surveys/supplemental-poverty-measure/datasets/spm/spm_techdoc.pdf |
| SPM README | https://www2.census.gov/programs-surveys/supplemental-poverty-measure/datasets/spm/readme.pdf |
| BLS SPM thresholds | https://www.bls.gov/pir/spmhome.htm |
| BLS 2024 thresholds | https://www.bls.gov/pir/spm/spm_thresholds_2024.htm |
| BLS 2019 methodology changes | https://www.bls.gov/pir/spm/spm_2019re_changes.htm |

---

## Appendix: ACS-Based Extension to 2010–2017 (Inactive)

The pipeline scripts contain fully functional code for computing the same adequacy ratio percentiles using Census **ACS-based SPM research extracts** for income years 2010–2017. This code is not disabled or commented out — it is active but gated by a year range parameter. The published outputs include only 2018–2024 (CPS ASEC) because mixing the two surveys creates a methodological break that complicates interpretation.

### How to re-enable

In both `03_batch_run.R` and `05_summary_stats.R`, change:

```r
YEARS_TO_RUN <- 2018:2024
```

to:

```r
YEARS_TO_RUN <- 2010:2024
```

The scripts handle both file series automatically based on year: years ≤ 2017 trigger the ACS path, years ≥ 2018 trigger the CPS ASEC path.

### How the ACS computation differs

The same three-step methodology applies (collapse to unit → compute adequacy → exact weighted percentile), but the data loading differs:

- **File format:** `.dta` (Stata) files read via the `haven` package, rather than CSV zips
- **File source:** Census SPM datasets page (`census.gov/topics/income-poverty/supplemental-poverty-measure/data/datasets.html`), not the CPS ASEC page
- **Unit identification:** No `SPM_Head` column exists in ACS files. Units are deduplicated by taking the first record per `SPM_ID` after sorting by `sporder` — equivalent to selecting the reference person
- **Weight column:** Named `wt` in ACS files (not `SPM_Weight`); normalized by `normalize_spm_colnames()` before processing
- **Weight scale:** ACS weights sum directly to ~125–130M (the estimated US SPM unit population); no ×100 division needed
- **Sample size:** ~1.2–1.3 million SPM unit rows per year, versus ~60,000 for CPS ASEC

### Methodological caveats for the ACS series

- **Different survey:** The ACS is a much larger survey (~3M households/year) but uses different income collection instruments than the CPS ASEC. The SPM variables are computed from ACS-reported income, which differs in coverage and reference period from CPS ASEC income.
- **Not the official SPM:** The Census Bureau's official annual SPM report is based on CPS ASEC. The ACS-based SPM extracts are a research product intended for sub-national estimation, not for replicating the headline national SPM figures.
- **Structural break at 2017→2018:** Adequacy ratio levels are broadly comparable across the break (same SPM variable definitions, same threshold methodology), but the surveys have different income underreporting characteristics and sampling frames. Any trend crossing this break should be interpreted with caution.
- **IPUMS CPS as alternative:** IPUMS CPS carries harmonized CPS ASEC SPM variables back to income year 2010, which would provide a fully consistent survey methodology across the entire 2010–2024 range. This is the preferred path for extending the series if access is obtained.
