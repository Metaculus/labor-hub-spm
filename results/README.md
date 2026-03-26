# Results

All outputs from the SPM adequacy ratio analysis. Income years 2018–2024, CPS ASEC microdata.

---

## Files

### `spm_adequacy_by_percentile.csv` — main result

One row per year × percentile (21 rows total). This is the primary output of the analysis.

| Column | Description |
|---|---|
| `ref_year` | Income reference year |
| `percentile` | 20, 50, or 80 |
| `adequacy_ratio` | Exact weighted percentile of `SPM_Resources / SPM_PovThreshold` |
| `n_units` | Number of SPM family units in that year's survey file (unweighted) |
| `note` | Structural break or policy context flag, where applicable |

### `spm_adequacy_summary_wide.csv` — wide format

Same data reshaped to one row per year with P20/P50/P80 as separate columns. Convenient for pasting into a spreadsheet or forecast model.

| Column | Description |
|---|---|
| `ref_year` | Income reference year |
| `P20_adequacy` | 20th percentile adequacy ratio |
| `P50_adequacy` | 50th percentile adequacy ratio |
| `P80_adequacy` | 80th percentile adequacy ratio |

### `spm_adequacy_trend.png` — chart

Trend lines for P20/P50/P80 from 2018–2024 with structural break annotations.

### `summary_stats/spm_summary_stats.csv` — rich per-year detail

Extends the main result with income levels, poverty rates, and characteristics of the representative family at each percentile. See [`summary_stats/README.md`](summary_stats/README.md) for the full column dictionary.

### `logs/` — run logs

Console output from pipeline runs. Informational only — not needed to interpret results.

---

## How to read the adequacy ratio

The adequacy ratio is `SPM_Resources / SPM_PovThreshold`:

- **Resources** = what a family actually has: cash income + in-kind benefits (SNAP, housing, etc.) + refundable tax credits (EITC) − federal/state/FICA taxes − work and childcare expenses − medical out-of-pocket costs
- **Threshold** = what that specific family needs: adjusted for family size and local housing costs

| Ratio | Meaning |
|---|---|
| < 1.0 | Below the SPM poverty line |
| = 1.0 | Exactly at the poverty line |
| 1.0 – 1.25 | Above poverty but within 25% of the threshold ("near poor") |
| 2.0 | Twice the resources needed to meet the threshold |

The **P20** ratio is the adequacy of the family at the 20th percentile of the well-being distribution — the point where 20% of all US families have lower adequacy. Likewise for P50 and P80.

---

## Year-specific notes

| Year | Note |
|---|---|
| 2019 | Recommended pre-COVID baseline |
| 2020 | CPS ASEC conducted by telephone only due to COVID; use with caution |
| 2021 | Elevated by ARPA one-time policies (expanded CTC, stimulus, enhanced UI) — not a structural improvement; do not use as baseline |
| 2023 | Recommended post-ARPA baseline (reversion to pre-COVID trend) |

---

## Further reading

- **Methodology and caveats:** [`../methodology.md`](../methodology.md)
- **Summary stats column dictionary:** [`summary_stats/README.md`](summary_stats/README.md)
- **Replication from scratch:** [`../README.md`](../README.md)
