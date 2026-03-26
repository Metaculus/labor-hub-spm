# SPM Adequacy Ratio: Methodology, Reflections, and Caveats

**Analysis goal:** For each income year 2018–2024, compute the exact weighted 20th, 50th, and 80th percentile of the SPM adequacy ratio distribution (SPM_Resources / SPM_PovThreshold) to serve as a forecasting anchor for assessing AI-era changes in living standards through 2030 and 2035.

**Coverage note:** The active series uses CPS ASEC microdata only (income years 2018–2024), which ensures a consistent survey methodology across all years. ACS-based SPM research extracts exist for 2010–2017 and the full pipeline for those years is preserved in `03_batch_run.R` and `05_summary_stats.R` (set `YEARS_TO_RUN <- 2010:2024` to re-enable), but they are excluded from published outputs due to the ACS/CPS ASEC structural break. IPUMS CPS may provide consistent CPS ASEC-based SPM data back to 2010 and is a candidate for future extension.

---

## 1. Core Methodology

### Data source

Two file series cover the full 2010–2024 range:

**Series A (reference years 2010–2017):** SPM research extract `.dta` files published by the Census Bureau at the SPM datasets page. These are **ACS-based** (American Community Survey), person-level files with ~1.2–1.3 million rows per year. Unlike the CPS ASEC series, they have large samples (~1.3M SPM units) but use ACS income reference conventions. All SPM variables needed for this analysis are present in these files.

**Series B (reference years 2018–2024):** Main CPS ASEC person file CSV zips from the Census CPS datasets page. These are **CPS ASEC-based** (~58,000–72,000 SPM units per year). SPM variables are embedded directly in the main person file from survey year 2019 onward.

The two series use the same SPM variable definitions and produce consistent adequacy ratio estimates at weighted percentiles. The key structural differences are:
- Sample size: ~1.3M (Series A) vs ~60K (Series B)
- Weight scale: Series A weights sum to ~125–130M (direct unit count); Series B weights are stored ×100 (sum to ~13B; divide by 100 to get ~130M population count)
- Unit identification: Series A has no `SPM_Head` column — deduplicate by `SPM_ID` (first record per unit, sorted by `sporder`) to get unit-level rows. Series B uses `SPM_Head == 1` directly.
- Series A weight column is named `wt`; normalized to `SPM_Weight` by `normalize_spm_colnames()`.

**Income reference period:** CPS ASEC asks about income in the **prior calendar year**, giving a clean annual reference. Series A (ACS-based) also reports on prior-year income.

**Most recent data:** 2025 CPS ASEC covering income year 2024 (released September 2025).

---

### Step 1: Collapse to SPM unit level

**Series B:** Filter to `SPM_Head == 1`. SPM variables are stored on every person record; keeping only the head gives one row per SPM unit. Validate with `uniqueN(SPM_ID) == nrow(dt)` after filtering.

**Series A:** No `SPM_Head` column. Deduplicate by `SPM_ID`, keeping the first record per unit sorted by `sporder`. This is equivalent to selecting the head of each unit.

Use `SPM_Weight` (normalized from `wt` for Series A) as the unit weight throughout.

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

Sort units by `adequacy` (ascending). Compute the weighted cumulative distribution using `SPM_Weight` (coerced to numeric/double before `cumsum()` to avoid 32-bit integer overflow — total weights sum to ~13B for Series B).

For each target percentile p ∈ {0.20, 0.50, 0.80}, the reported value is the first `adequacy` value where the cumulative weight meets or exceeds `p × total_weight` (standard type-1 weighted quantile / lower).

No percentile bands are used. With ~60,000 SPM units (Series B) and ~1.3M units (Series A), exact weighted percentiles at P20/P50/P80 are stable.

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

### 4.7 Series A / Series B structural break (2017→2018)

Series A (2010–2017) is ACS-based with ~1.3M sample units per year. Series B (2018–2024) is CPS ASEC-based with ~60K units. The weighted adequacy percentiles are consistent across the break (both use the same SPM variable definitions and nationally representative weights), but sample sizes differ by a factor of ~20. Any uncertainty bands would be much tighter for Series A years. The break also coincides with the 2018 pre-COVID improvement in adequacy ratios, so care is needed in attributing trends.

### 4.8 SPM methodology changes over time

The series has undergone structural changes: broadband subsidies added in 2021 (CPS ASEC SPM only), MOOP imputation changes, the 3→5 year CE window change in 2020 thresholds, and the 2014 CPS ASEC questionnaire redesign affecting high-income respondents. All are annotated in the output.

### 4.9 AI impact attribution

The ratio will move with productivity growth, policy changes, inflation, demographic shifts, and sector-specific labor market changes. Isolating the AI effect from these confounders is not possible from this measure alone.

---

## 5. Historical Reach and Structural Breaks

**Full series: income years 2010–2024** (15 years).

| Income year(s) | Note |
|---|---|
| 2010–2012 | Early SPM methodology; treat with more caution |
| 2014–2015 | CPS ASEC questionnaire redesign; may affect P80 level |
| 2017→2018 | Series break: ACS-based (Series A) to CPS ASEC-based (Series B) |
| 2020 | COVID field limitations (telephone-only interviews) |
| 2021 | ARPA policy spike (expanded CTC, stimulus, enhanced UI) — do not use as baseline |
| 2019 or 2023 | Recommended baseline years: 2019 = pre-COVID, 2023 = post-ARPA reversion |

**Pre-2010:** SPM was not published before the 2011 CPS ASEC. The Wimer et al. historical SPM series provides pre-2010 estimates using a different methodology; do not concatenate without explicit bridging.

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
4. The 2021 ARPA spike makes it a poor baseline; use 2019 (pre-COVID) or 2023 (post-ARPA reversion) as anchors.
5. The Series A→B break at 2018 should be noted when describing any trend from 2017→2018.

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
