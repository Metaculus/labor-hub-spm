# Summary Statistics — Column Dictionary

**File:** `spm_summary_stats.csv`

One row per income year (2018–2024). All dollar values are nominal (not inflation-adjusted). All weighted percentiles use `SPM_Weight` as the unit weight.

---

## Identifiers

| Column | Description |
|---|---|
| `ref_year` | Income reference year (e.g., 2024 = income earned during calendar year 2024) |
| `data_series` | `B_CPS_ASEC` for all rows — Census CPS ASEC public-use person file |

---

## Unit counts

| Column | Description |
|---|---|
| `n_units_sample` | Number of SPM family units in the survey file (unweighted rows after filtering to one row per unit and dropping invalid thresholds) |
| `n_units_population` | Estimated total US SPM family units represented (weighted count, in actual units — ~130–142 million) |

> **Weight note:** CPS ASEC stores `SPM_Weight` scaled ×100. `n_units_population` divides by 100 to recover the actual estimated count.

---

## Marginal distributions

These columns report the weighted percentile of each variable across the full distribution independently. They are **not** conditioned on any other variable — e.g., `totval_p20` is the 20th percentile of SPM_Totval regardless of where those families fall in the adequacy distribution.

### SPM_Totval (pre-expense resources)

| Column | Description |
|---|---|
| `totval_p20` | 20th percentile of SPM_Totval — cash income plus in-kind benefits, before subtracting work/medical expenses and taxes |
| `totval_p50` | 50th percentile |
| `totval_p80` | 80th percentile |

### SPM_Resources (final post-expense resources)

| Column | Description |
|---|---|
| `resources_p20` | 20th percentile of SPM_Resources — Totval minus taxes, work expenses, childcare, and medical out-of-pocket |
| `resources_p50` | 50th percentile |
| `resources_p80` | 80th percentile |

### SPM_PovThreshold (poverty threshold)

| Column | Description |
|---|---|
| `threshold_p20` | 20th percentile of SPM_PovThreshold — varies by family size and local housing costs |
| `threshold_p50` | 50th percentile |
| `threshold_p80` | 80th percentile |

### Adequacy ratio (main analysis variable)

| Column | Description |
|---|---|
| `adequacy_p20` | 20th percentile of `SPM_Resources / SPM_PovThreshold` — the primary output of the analysis |
| `adequacy_p50` | 50th percentile |
| `adequacy_p80` | 80th percentile |

---

## Characteristics of units at each adequacy percentile

These columns describe the **single representative family unit** sitting exactly at the 20th, 50th, or 80th percentile of the adequacy ratio distribution. This lets you see the concrete situation of the family that defines each percentile.

### At the P20 adequacy unit

| Column | Description |
|---|---|
| `at_p20_totval` | That family's SPM_Totval (pre-expense resources), in dollars |
| `at_p20_resources` | That family's SPM_Resources (post-expense resources), in dollars |
| `at_p20_threshold` | That family's SPM poverty threshold, in dollars |
| `at_p20_adequacy` | That family's adequacy ratio (= `at_p20_resources / at_p20_threshold`; matches `adequacy_p20`) |
| `at_p20_num_persons` | Number of people in that family unit |
| `at_p20_equiv_scale` | Equivalence scale used to adjust the threshold for family size |

### At the P50 adequacy unit

Same columns prefixed `at_p50_`: totval, resources, threshold, adequacy, num_persons, equiv_scale.

### At the P80 adequacy unit

Same columns prefixed `at_p80_`: totval, resources, threshold, adequacy, num_persons, equiv_scale.

---

## Distribution-level diagnostics

| Column | Description |
|---|---|
| `mean_adequacy` | Weighted mean of the adequacy ratio across all units |
| `pct_below_poverty` | % of units with adequacy < 1.0 (in SPM poverty) |
| `pct_deep_poverty` | % of units with adequacy < 0.5 (deep poverty — resources less than half the threshold) |
| `pct_near_poverty` | % of units with 1.0 ≤ adequacy < 1.25 (above poverty but within 25% of threshold) |
| `pct_neg_resources` | % of units with SPM_Resources < 0 (large expense burdens exceeding income; rare edge cases) |

---

## Key interpretation notes

- **Ratio = 1.0** means the family's resources exactly equal its poverty threshold — neither in poverty nor comfortable above it.
- **Ratio = 2.0** means the family has twice the resources needed to meet its threshold.
- The adequacy ratio accounts for both family size (via EquivScale) and geographic cost variation (via GeoAdj embedded in the threshold), making it comparable across family types and locations.
- **2021 values** are elevated due to ARPA one-time policies (expanded Child Tax Credit, stimulus payments, enhanced unemployment insurance). Do not use 2021 as a structural baseline.
- **2019 and 2023** are the recommended baseline years: 2019 = pre-COVID, 2023 = post-ARPA reversion to trend.
- Dollar values are **nominal** — not adjusted for inflation across years.
