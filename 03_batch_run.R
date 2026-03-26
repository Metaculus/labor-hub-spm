# 03_batch_run.R
# Orchestrates the full multi-year run.
# Downloads missing files, processes each year, saves output.
#
# Usage:
#   source("03_batch_run.R")
#
# Options:
#   DELETE_RAW_AFTER_PROCESSING  — removes each raw file after processing
#                                   to save disk space (default FALSE — keep files
#                                   locally so re-runs don't re-download)
#   SKIP_COMPLETED_YEARS         — skip years already present in output CSV (default TRUE)
#   YEARS_TO_RUN                 — subset of ref years if you want a partial run
#                                   (default: all available years)

library(data.table)

DELETE_RAW_AFTER_PROCESSING <- FALSE   # keep raw files; re-runs use local copies
SKIP_COMPLETED_YEARS        <- TRUE    # skip years already in output CSV
# Default: CPS ASEC years only (consistent methodology).
# To include ACS-based Series A years (2010-2017), change to 2010:2024.
# The Series A pipeline code below is preserved and will run if those years
# are added back to YEARS_TO_RUN (e.g. once IPUMS CPS coverage is confirmed).
YEARS_TO_RUN <- 2018:2024

RAW_DIR    <- "data/raw"
OUTPUT_DIR <- "results"
dir.create(RAW_DIR,                   recursive = TRUE, showWarnings = FALSE)
dir.create(OUTPUT_DIR,                recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUTPUT_DIR, "logs"), recursive = TRUE, showWarnings = FALSE)

# Increase download timeout for large files (Series A .dta files are ~650 MB)
options(timeout = 600)

source("01_download.R")   # defines series_a and series_b data frames; downloads files
source("02_process_year.R")

# ---------------------------------------------------------------------------
# Annotations (for output and charts)
# ---------------------------------------------------------------------------

ANNOTATIONS <- data.table(
  ref_year = c(2019, 2020, 2021),
  note = c(
    "Pre-COVID baseline",
    "COVID field limitations (telephone-only)",
    "ARPA policy spike (CTC, stimulus, enhanced UI)"
  )
)
# Notes for ACS-based years (2010-2017) are preserved here for reference.
# Uncomment and add back to ANNOTATIONS if those years are re-enabled:
#   2010-2012: "Early SPM methodology"
#   2014:      "CPS ASEC questionnaire redesign (partial)"
#   2015:      "CPS ASEC questionnaire redesign (full)"

# ---------------------------------------------------------------------------
# Load already-completed years from existing output (if any)
# ---------------------------------------------------------------------------

output_long_path <- file.path(OUTPUT_DIR, "spm_adequacy_by_percentile.csv")

completed_years <- integer(0)
existing_results <- NULL

if (SKIP_COMPLETED_YEARS && file.exists(output_long_path)) {
  existing_results <- fread(output_long_path)
  # Keep only years within the active YEARS_TO_RUN range so that ACS-based
  # rows (2010-2017) from prior runs are not carried forward into the output.
  existing_results <- existing_results[ref_year %in% YEARS_TO_RUN]
  # A year is complete only if all 3 percentile bands have non-NA results
  year_counts     <- existing_results[!is.na(adequacy_ratio), .N, by = ref_year]
  completed_years <- year_counts[N >= 3L, ref_year]  # 3 = P20 + P50 + P80
  if (length(completed_years) > 0) {
    message("Skipping already-completed years: ", paste(sort(completed_years), collapse = ", "))
  }
}

# ---------------------------------------------------------------------------
# Run all years
# ---------------------------------------------------------------------------

all_results <- vector("list", length(YEARS_TO_RUN))
names(all_results) <- as.character(YEARS_TO_RUN)

for (yr in YEARS_TO_RUN) {

  if (yr %in% completed_years) {
    message("\n--- ref_year = ", yr, " already in output, skipping. ---")
    next
  }

  message("\n--- Processing ref_year = ", yr, " ---")

  if (yr <= 2017) {
    # Series A: SPM research extract
    row <- series_a[series_a$ref_year == yr, ]
    if (nrow(row) == 0) { message("  No entry in registry for ", yr, ", skipping."); next }

    if (!file.exists(row$local_path)) {
      message("  File not found: ", row$local_path, " — attempting download.")
      download_if_missing(row$url, row$local_path, paste0("SPM extract ref_year=", yr))
    }

    if (!file.exists(row$local_path)) { message("  Download failed, skipping."); next }

    all_results[[as.character(yr)]] <- tryCatch(
      process_series_a(row$local_path, yr, delete_after = DELETE_RAW_AFTER_PROCESSING),
      error = function(e) { message("  ERROR: ", conditionMessage(e)); NULL }
    )

  } else {
    # Series B: CPS ASEC main CSV zip
    row <- series_b[series_b$ref_year == yr, ]
    if (nrow(row) == 0) { message("  No entry in registry for ", yr, ", skipping."); next }

    if (!file.exists(row$local_path)) {
      message("  File not found: ", row$local_path, " — attempting download.")
      download_if_missing(row$url, row$local_path, paste0("ASEC zip ref_year=", yr))
    }

    if (!file.exists(row$local_path)) { message("  Download failed, skipping."); next }

    all_results[[as.character(yr)]] <- tryCatch(
      process_series_b(row$local_path, yr, row$survey_year,
                       delete_after = DELETE_RAW_AFTER_PROCESSING),
      error = function(e) { message("  ERROR: ", conditionMessage(e)); NULL }
    )
  }
}

# ---------------------------------------------------------------------------
# Combine with any existing results and save
# ---------------------------------------------------------------------------

new_results <- rbindlist(Filter(Negate(is.null), all_results))

# Merge with previously completed years (if any)
if (!is.null(existing_results) && nrow(new_results) > 0) {
  # Drop old rows for any years we just reprocessed, then append
  keep_old <- existing_results[!ref_year %in% new_results$ref_year]
  results  <- rbindlist(list(keep_old, new_results), fill = TRUE)
} else if (!is.null(existing_results)) {
  results <- existing_results
} else {
  results <- new_results
}

if (nrow(results) == 0) {
  message("\nNo results to save.")
  stop("No years processed successfully.")
}

# Add annotations (drop any pre-existing note column to avoid merge conflict)
if ("note" %in% names(results)) results[, note := NULL]
results <- merge(results, ANNOTATIONS, by = "ref_year", all.x = TRUE)
results[is.na(note), note := ""]

# Long format
setorder(results, ref_year, percentile)
fwrite(results, output_long_path)
message("\nSaved: ", output_long_path)

# Wide format (for question framing / sharing)
wide <- dcast(results[, .(ref_year, percentile, adequacy_ratio)],
              ref_year ~ percentile, value.var = "adequacy_ratio")
setnames(wide, as.character(c(20, 50, 80)), c("P20_adequacy", "P50_adequacy", "P80_adequacy"))
fwrite(wide, file.path(OUTPUT_DIR, "spm_adequacy_summary_wide.csv"))
message("Saved: ", file.path(OUTPUT_DIR, "spm_adequacy_summary_wide.csv"))

# Print summary
message("\n=== Results ===")
print(wide)
