# 02_process_year.R
# Core processing function: one year of data → 3-row summary
# (one row per percentile target: P20, P50, P80).
#
# Methodology: rank SPM units by adequacy ratio (SPM_Resources / SPM_PovThreshold),
# then report the exact weighted 20th, 50th, and 80th percentile adequacy values.
# This ranks units by their final need-adjusted well-being, accounting for both
# family size and geographic cost variation embedded in SPM_PovThreshold.
#
# Handles both file series:
#   Series A: SPM research extract .dta  (ref years 2010-2017)
#   Series B: CPS ASEC main CSV zip      (ref years 2018-2024)

library(data.table)

# ---------------------------------------------------------------------------
# Column name normalisation
# Handles capitalisation differences across file vintages.
# ---------------------------------------------------------------------------

normalize_spm_colnames <- function(dt) {
  # Build a lookup of lowercase → canonical name.
  # Includes alternate names used in older Series A research extracts
  # (e.g. "wt" for the weight column in 2010-2017 .dta files).
  canonical <- c(
    spm_head          = "SPM_Head",
    spm_id            = "SPM_ID",
    spm_weight        = "SPM_Weight",
    wt                = "SPM_Weight",   # Series A early vintages (2010-2017)
    spm_totval        = "SPM_Totval",
    spm_equivscale    = "SPM_EquivScale",
    spm_resources     = "SPM_Resources",
    spm_povthreshold  = "SPM_PovThreshold",
    spm_numper        = "SPM_NumPer",
    spm_poor          = "SPM_Poor"   # optional, used for cross-check
  )
  current <- tolower(names(dt))
  for (lower_name in names(canonical)) {
    idx <- which(current == lower_name)
    if (length(idx) == 1 && names(dt)[idx] != canonical[lower_name]) {
      setnames(dt, names(dt)[idx], canonical[lower_name])
    }
  }
  dt
}

# ---------------------------------------------------------------------------
# Load data — selects only the columns needed
# ---------------------------------------------------------------------------

NEEDED_COLS <- c("SPM_Head", "SPM_ID", "SPM_Weight",
                 "SPM_Resources", "SPM_PovThreshold")

load_series_a <- function(dta_path) {
  # SPM research extract (.dta): haven, then data.table
  if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' required for .dta files.")
  raw <- haven::read_dta(dta_path)
  dt  <- as.data.table(raw)
  normalize_spm_colnames(dt)

  # Older Series A files (2010-2017) have no SPM_Head column.
  # They are person-level but SPM unit variables repeat across members.
  # Synthesise SPM_Head by keeping the first record per SPM_ID
  # (lowest sporder, or just first row if sporder absent).
  if (!"SPM_Head" %in% names(dt)) {
    message("  SPM_Head not found — deduplicating by SPM_ID to get unit-level rows.")
    if ("sporder" %in% tolower(names(dt))) {
      order_col <- names(dt)[tolower(names(dt)) == "sporder"][1]
      setorderv(dt, c("SPM_ID", order_col))
    }
    dt <- dt[, .SD[1L], by = SPM_ID]
    dt[, SPM_Head := 1L]
  }

  # Keep only needed columns (case-insensitive match already done above)
  keep <- intersect(NEEDED_COLS, names(dt))
  missing <- setdiff(NEEDED_COLS, names(dt))
  if (length(missing) > 0) stop("Missing columns in Series A file: ", paste(missing, collapse = ", "))
  dt[, ..keep]
}

load_series_b <- function(zip_path, yy) {
  # CPS ASEC CSV zip: extract person file, fread with select=
  person_file <- paste0("pppub", yy, ".csv")
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # List contents to verify person file name
  contents <- unzip(zip_path, list = TRUE)$Name
  if (!person_file %in% contents) {
    # Fallback: find any file matching "pppubNN.csv" anywhere in the zip path
    candidates <- grep(paste0("pppub", yy, "\\.csv$"), contents,
                       value = TRUE, ignore.case = TRUE)
    if (length(candidates) == 0) {
      # Broader fallback: any file starting with "pp" anywhere in path
      candidates <- grep("(^|/)pp[^/]+\\.csv$", contents, value = TRUE, ignore.case = TRUE)
    }
    if (length(candidates) == 1) {
      person_file <- candidates[1]
      message("  Using person file: ", person_file)
    } else {
      stop("Cannot identify person file in zip. Contents: ", paste(contents, collapse = ", "))
    }
  }

  unzip(zip_path, files = person_file, exdir = tmp_dir)
  csv_path <- file.path(tmp_dir, person_file)

  # Read header to identify the exact column names (may be uppercase)
  header <- names(fread(csv_path, nrows = 0))
  header_lower <- tolower(header)
  needed_lower <- tolower(NEEDED_COLS)
  matched_cols <- header[match(needed_lower, header_lower)]
  if (any(is.na(matched_cols))) {
    stop("Missing columns in person file: ",
         paste(NEEDED_COLS[is.na(matched_cols)], collapse = ", "))
  }

  dt <- fread(csv_path, select = matched_cols)
  normalize_spm_colnames(dt)
  dt
}

# ---------------------------------------------------------------------------
# Weighted quantile helper
# ---------------------------------------------------------------------------

weighted_quantile <- function(x, w, probs) {
  # Standard weighted quantile (type 1 / lower):
  # for each p, return the first x where cumulative weight >= p * total_weight.
  # Coerces to numeric to handle haven_labelled columns from .dta files.
  x     <- as.numeric(x)
  w     <- as.numeric(w)
  ord   <- order(x)
  x_s   <- x[ord]
  w_s   <- w[ord]
  cw    <- cumsum(w_s)
  total <- cw[length(cw)]
  vapply(probs, function(p) x_s[which(cw >= p * total)[1L]], numeric(1L))
}

# ---------------------------------------------------------------------------
# Core processing function
# ---------------------------------------------------------------------------

# Exact percentile targets (no bands)
PERCENTILE_TARGETS <- c(P20 = 0.20, P50 = 0.50, P80 = 0.80)

process_spm_year <- function(dt, ref_year) {
  # dt must already have normalised column names and all NEEDED_COLS present

  # 1. Collapse to SPM unit level
  dt <- dt[SPM_Head == 1]

  # Validate uniqueness
  n_units    <- nrow(dt)
  n_unique   <- uniqueN(dt$SPM_ID)
  if (n_units != n_unique) {
    warning(ref_year, ": SPM_ID not unique after filtering to SPM_Head == 1. ",
            n_units, " rows, ", n_unique, " unique IDs.")
  }

  # 2. Drop records with invalid threshold
  dt <- dt[SPM_PovThreshold > 0]
  n_units <- nrow(dt)

  # 3. Compute adequacy ratio — ranking variable and outcome are the same
  dt[, adequacy := SPM_Resources / SPM_PovThreshold]

  # 4. Exact weighted percentiles of the adequacy distribution
  wq <- weighted_quantile(dt$adequacy, dt$SPM_Weight, probs = PERCENTILE_TARGETS)

  data.table(
    ref_year       = ref_year,
    percentile     = as.integer(sub("P", "", names(PERCENTILE_TARGETS))),
    adequacy_ratio = round(wq, 4),
    n_units        = n_units   # total SPM units (same for all three rows)
  )
}

# ---------------------------------------------------------------------------
# Top-level convenience wrappers
# ---------------------------------------------------------------------------

process_series_a <- function(dta_path, ref_year, delete_after = FALSE) {
  message("  Loading Series A (SPM extract): ", basename(dta_path))
  dt <- load_series_a(dta_path)
  result <- process_spm_year(dt, ref_year)
  if (delete_after) {
    file.remove(dta_path)
    message("  Deleted: ", basename(dta_path))
  }
  result
}

process_series_b <- function(zip_path, ref_year, survey_year, delete_after = FALSE) {
  yy <- formatC(survey_year %% 100, width = 2, flag = "0")
  message("  Loading Series B (ASEC CSV zip): ", basename(zip_path))
  dt <- load_series_b(zip_path, yy)
  result <- process_spm_year(dt, ref_year)
  if (delete_after) {
    file.remove(zip_path)
    message("  Deleted: ", basename(zip_path))
  }
  result
}
