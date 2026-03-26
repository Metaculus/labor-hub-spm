# 01_download.R
# Downloads CPS ASEC and SPM research extract files needed for the analysis.
# Safe to re-run: skips files that already exist on disk.
#
# Series A (ref years 2010-2017): SPM research extract .dta files
#   from https://www2.census.gov/programs-surveys/supplemental-poverty-measure/datasets/spm/
# Series B (ref years 2018-2024): CPS ASEC main person file CSV zips
#   from https://www2.census.gov/programs-surveys/cps/datasets/[SURVEY_YEAR]/march/

library(utils)

# Increase timeout for large files (~650 MB Series A .dta files)
# Can be overridden before sourcing this file.
if (getOption("timeout") < 600) options(timeout = 600)

RAW_DIR <- "data/raw"
dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# File registries
# ---------------------------------------------------------------------------

# Series A: SPM research extracts (ref years 2010-2017)
SPM_EXTRACT_BASE <- "https://www2.census.gov/programs-surveys/supplemental-poverty-measure/datasets/spm"

series_a <- data.frame(
  ref_year  = 2010:2017,
  filename  = paste0("spm_", 2010:2017, "_pu.dta"),
  stringsAsFactors = FALSE
)
series_a$url <- file.path(SPM_EXTRACT_BASE, series_a$filename)
series_a$local_path <- file.path(RAW_DIR, series_a$filename)

# Series B: CPS ASEC main CSV zips (ref years 2018-2024, survey years 2019-2025)
ASEC_BASE <- "https://www2.census.gov/programs-surveys/cps/datasets"

series_b <- data.frame(
  ref_year    = 2018:2024,
  survey_year = 2019:2025,
  stringsAsFactors = FALSE
)
series_b$yy       <- formatC(series_b$survey_year %% 100, width = 2, flag = "0")
series_b$zip_name <- paste0("asecpub", series_b$yy, "csv.zip")
series_b$url      <- file.path(ASEC_BASE, series_b$survey_year, "march", series_b$zip_name)
series_b$local_path <- file.path(RAW_DIR, series_b$zip_name)

# ---------------------------------------------------------------------------
# Download helpers
# ---------------------------------------------------------------------------

download_if_missing <- function(url, dest, label) {
  if (file.exists(dest)) {
    message(label, ": already on disk, skipping.")
    return(invisible(dest))
  }
  message(label, ": downloading from ", url)
  tryCatch(
    download.file(url, dest, mode = "wb", quiet = FALSE),
    error = function(e) {
      message("  ERROR downloading ", label, ": ", conditionMessage(e))
      if (file.exists(dest)) file.remove(dest)  # remove partial download
    }
  )
  invisible(dest)
}

# ---------------------------------------------------------------------------
# List contents of a zip without extracting
# ---------------------------------------------------------------------------

list_zip_contents <- function(zip_path) {
  tryCatch(unzip(zip_path, list = TRUE)$Name, error = function(e) character(0))
}

# ---------------------------------------------------------------------------
# Download all files
# ---------------------------------------------------------------------------

message("\n=== Series A: SPM research extracts (ref years 2010-2017) ===")
for (i in seq_len(nrow(series_a))) {
  download_if_missing(series_a$url[i], series_a$local_path[i],
                      paste0("SPM extract ref_year=", series_a$ref_year[i]))
}

message("\n=== Series B: CPS ASEC CSV zips (ref years 2018-2024) ===")
for (i in seq_len(nrow(series_b))) {
  zip_path <- series_b$local_path[i]
  download_if_missing(series_b$url[i], zip_path,
                      paste0("ASEC zip ref_year=", series_b$ref_year[i]))

  # Verify expected person file is present inside the zip
  if (file.exists(zip_path)) {
    expected_person_file <- paste0("pppub", series_b$yy[i], ".csv")
    contents <- list_zip_contents(zip_path)
    if (expected_person_file %in% contents) {
      message("  Person file confirmed: ", expected_person_file)
    } else {
      message("  WARNING: expected '", expected_person_file,
              "' not found in zip. Contents: ", paste(contents, collapse = ", "))
    }
  }
}

message("\nDownload complete. Files are in: ", RAW_DIR)
