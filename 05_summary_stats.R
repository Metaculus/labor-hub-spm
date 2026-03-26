# 05_summary_stats.R
# Produces a rich per-year summary statistics file.
#
# For each year includes:
#   - Sample and population unit counts
#   - Weighted 20th/50th/80th percentiles of the marginal distributions of
#     SPM_Totval, SPM_Resources, and SPM_PovThreshold
#   - For the unit sitting AT the 20th/50th/80th adequacy percentile:
#       totval, resources, threshold, adequacy ratio, num persons, equiv scale
#   - Weighted mean adequacy ratio
#   - % of units below SPM poverty line (adequacy < 1.0)
#   - % of units in deep poverty (adequacy < 0.5)
#   - % of units with negative SPM_Resources (large expense burdens)
#
# Run after 03_batch_run.R; requires raw data files in data/raw/.

library(data.table)

RAW_DIR    <- "data/raw"
OUTPUT_DIR <- "results/summary_stats"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

source("01_download.R")       # defines series_a, series_b, download_if_missing
source("02_process_year.R")   # defines load functions and weighted_quantile

# Override NEEDED_COLS *after* sourcing 02_process_year.R (which resets it to
# the minimal 5-column set). The load functions reference NEEDED_COLS at call
# time, so setting it here before the loop is sufficient.
NEEDED_COLS <- c(
  "SPM_Head", "SPM_ID", "SPM_Weight",
  "SPM_Totval", "SPM_EquivScale", "SPM_NumPer",
  "SPM_Resources", "SPM_PovThreshold"
)

# Default: CPS ASEC years only. Change to 2010:2024 to include ACS-based years.
YEARS_TO_RUN <- 2018:2024

# ---------------------------------------------------------------------------
# Helper: characteristics of the single unit sitting at weighted percentile p
# ---------------------------------------------------------------------------

unit_at_pctile <- function(dt_sorted, cum_wt, total_wt, p) {
  # dt_sorted must already be sorted by adequacy ascending with cum_wt column
  idx <- which(cum_wt >= p * total_wt)[1L]
  dt_sorted[idx]
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

all_stats <- vector("list", length(YEARS_TO_RUN))
names(all_stats) <- as.character(YEARS_TO_RUN)

for (yr in YEARS_TO_RUN) {

  message("\n--- Summary stats ref_year = ", yr, " ---")

  # Load raw data
  dt <- tryCatch({
    if (yr <= 2017) {
      row <- series_a[series_a$ref_year == yr, ]
      if (nrow(row) == 0 || !file.exists(row$local_path)) stop("File not found")
      load_series_a(row$local_path)
    } else {
      row <- series_b[series_b$ref_year == yr, ]
      if (nrow(row) == 0 || !file.exists(row$local_path)) stop("File not found")
      yy <- formatC(row$survey_year %% 100, width = 2, flag = "0")
      load_series_b(row$local_path, yy)
    }
  }, error = function(e) {
    message("  LOAD ERROR: ", conditionMessage(e)); NULL
  })

  if (is.null(dt)) next

  # Filter to unit level; drop invalid thresholds
  dt <- dt[SPM_Head == 1 & SPM_PovThreshold > 0]

  # Coerce all numeric columns to plain double — haven reads .dta columns as
  # haven_labelled which breaks round(), order(), and arithmetic in some contexts.
  num_cols <- intersect(
    c("SPM_Totval", "SPM_EquivScale", "SPM_NumPer",
      "SPM_Resources", "SPM_PovThreshold", "SPM_Weight"),
    names(dt)
  )
  dt[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]

  # Compute adequacy ratio
  dt[, adequacy := SPM_Resources / SPM_PovThreshold]

  # Weights as numeric throughout to avoid integer overflow
  w <- dt$SPM_Weight   # already numeric from coercion above
  total_wt <- sum(w)

  # ---- Unit counts -------------------------------------------------------
  # CPS ASEC (Series B) stores SPM_Weight ×100 vs ACS (Series A) which stores
  # actual unit weights. Dividing by 100 for Series B gives the correct ~130M
  # US SPM unit population count and prevents integer overflow in output.
  n_sample       <- nrow(dt)
  weight_divisor <- if (yr <= 2017) 1 else 100
  n_population   <- as.numeric(round(total_wt / weight_divisor))

  # ---- Marginal weighted percentiles -------------------------------------
  wq_totval    <- weighted_quantile(dt$SPM_Totval,        w, c(0.20, 0.50, 0.80))
  wq_resources <- weighted_quantile(dt$SPM_Resources,     w, c(0.20, 0.50, 0.80))
  wq_threshold <- weighted_quantile(dt$SPM_PovThreshold,  w, c(0.20, 0.50, 0.80))
  wq_adequacy  <- weighted_quantile(dt$adequacy,          w, c(0.20, 0.50, 0.80))

  # ---- Units AT each adequacy percentile ---------------------------------
  setorder(dt, adequacy)
  dt[, cum_wt := cumsum(as.numeric(SPM_Weight))]

  get_unit <- function(p) unit_at_pctile(dt, dt$cum_wt, total_wt, p)

  u20 <- get_unit(0.20)
  u50 <- get_unit(0.50)
  u80 <- get_unit(0.80)

  # ---- Methodology diagnostics -------------------------------------------
  mean_adequacy        <- sum(dt$adequacy * w) / total_wt
  pct_below_poverty    <- sum(w[dt$adequacy <  1.0]) / total_wt * 100
  pct_deep_poverty     <- sum(w[dt$adequacy <  0.5]) / total_wt * 100
  pct_neg_resources    <- sum(w[dt$SPM_Resources < 0]) / total_wt * 100
  pct_near_poverty     <- sum(w[dt$adequacy >= 1.0 & dt$adequacy < 1.25]) / total_wt * 100

  # ---- Assemble row ------------------------------------------------------
  all_stats[[as.character(yr)]] <- data.table(
    ref_year            = yr,
    data_series         = if (yr <= 2017) "A_ACS" else "B_CPS_ASEC",

    # Unit counts
    # Note: Series A (ACS-based, ~1.3M sample rows) vs Series B (CPS ASEC, ~60K rows)
    # reflect different underlying surveys — not a comparability problem for weighted
    # percentiles, but n_units_sample is not directly comparable across the break.
    n_units_sample      = n_sample,
    n_units_population  = n_population,

    # Marginal P20/P50/P80 of SPM_Totval (pre-expense income + transfers)
    totval_p20          = round(wq_totval[1]),
    totval_p50          = round(wq_totval[2]),
    totval_p80          = round(wq_totval[3]),

    # Marginal P20/P50/P80 of SPM_Resources (final post-expense resources)
    resources_p20       = round(wq_resources[1]),
    resources_p50       = round(wq_resources[2]),
    resources_p80       = round(wq_resources[3]),

    # Marginal P20/P50/P80 of SPM_PovThreshold (need benchmark)
    threshold_p20       = round(wq_threshold[1]),
    threshold_p50       = round(wq_threshold[2]),
    threshold_p80       = round(wq_threshold[3]),

    # Adequacy ratio at each adequacy percentile (from main analysis)
    adequacy_p20        = round(wq_adequacy[1], 4),
    adequacy_p50        = round(wq_adequacy[2], 4),
    adequacy_p80        = round(wq_adequacy[3], 4),

    # Characteristics of the unit sitting AT P20 adequacy
    at_p20_totval       = round(u20$SPM_Totval),
    at_p20_resources    = round(u20$SPM_Resources),
    at_p20_threshold    = round(u20$SPM_PovThreshold),
    at_p20_adequacy     = round(u20$adequacy, 4),
    at_p20_num_persons  = u20$SPM_NumPer,
    at_p20_equiv_scale  = round(u20$SPM_EquivScale, 4),

    # Characteristics of the unit sitting AT P50 adequacy
    at_p50_totval       = round(u50$SPM_Totval),
    at_p50_resources    = round(u50$SPM_Resources),
    at_p50_threshold    = round(u50$SPM_PovThreshold),
    at_p50_adequacy     = round(u50$adequacy, 4),
    at_p50_num_persons  = u50$SPM_NumPer,
    at_p50_equiv_scale  = round(u50$SPM_EquivScale, 4),

    # Characteristics of the unit sitting AT P80 adequacy
    at_p80_totval       = round(u80$SPM_Totval),
    at_p80_resources    = round(u80$SPM_Resources),
    at_p80_threshold    = round(u80$SPM_PovThreshold),
    at_p80_adequacy     = round(u80$adequacy, 4),
    at_p80_num_persons  = u80$SPM_NumPer,
    at_p80_equiv_scale  = round(u80$SPM_EquivScale, 4),

    # Distribution-level diagnostics
    mean_adequacy       = round(mean_adequacy, 4),
    pct_below_poverty   = round(pct_below_poverty,  2),   # adequacy < 1.0
    pct_deep_poverty    = round(pct_deep_poverty,   2),   # adequacy < 0.5
    pct_near_poverty    = round(pct_near_poverty,   2),   # 1.0 <= adequacy < 1.25
    pct_neg_resources   = round(pct_neg_resources,  2)    # SPM_Resources < 0 (high expense burden)
  )

  message("  Done. n=", n_sample, " units, pop=", formatC(n_population, big.mark=",", format="d"))
}

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

results <- rbindlist(all_stats)
setorder(results, ref_year)

out_path <- file.path(OUTPUT_DIR, "spm_summary_stats.csv")
fwrite(results, out_path)
message("\nSaved: ", out_path)

# Print a few key columns for quick review
message("\n=== Key columns ===")
print(results[, .(ref_year, n_units_sample, adequacy_p20, adequacy_p50, adequacy_p80,
                  mean_adequacy, pct_below_poverty, pct_near_poverty, pct_neg_resources)])
