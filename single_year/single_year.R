# ==============================================================================
# SPM Adequacy Ratio — Single Year Computation
# ==============================================================================
#
# This script computes the 20th, 50th, and 80th percentile of the SPM
# adequacy ratio for one CPS ASEC file. It is meant to be read top to
# bottom and understood without any other context.
#
# The adequacy ratio = SPM_Resources / SPM_PovThreshold
#   - Resources:  what a family has (income + transfers - taxes - expenses)
#   - Threshold:  what that specific family needs (varies by size + location)
#   - Ratio > 1:  above the SPM poverty line
#   - Ratio = 1:  exactly at the SPM poverty line
#   - Ratio < 1:  below the SPM poverty line
#
# We rank families by their own adequacy ratio, so the 20th percentile
# is the family at the bottom fifth of the well-being distribution.
#
# Requires: data.table
#   install.packages("data.table")
#
# For Series A files (income years 2010-2017, .dta format):
#   Replace fread() with haven::read_dta() and see note at Step 1.
# ==============================================================================

library(data.table)

FILE_PATH <- "data/pppub25.csv"   # path relative to this script's folder
# Change "pppub25.csv" to the filename you downloaded (see data/README.md for instructions)


# ------------------------------------------------------------------------------
# Step 1: Load only the four columns we need and rename them for ease of reference
# ------------------------------------------------------------------------------

dt <- fread(FILE_PATH,
            select = c("SPM_HEAD", "SPM_WEIGHT", "SPM_RESOURCES", "SPM_POVTHRESHOLD"))

setnames(dt,
         old = c("SPM_HEAD", "SPM_WEIGHT", "SPM_RESOURCES", "SPM_POVTHRESHOLD"),
         new = c("head",      "weight",     "resources",     "threshold"))


# ------------------------------------------------------------------------------
# Step 2: Keep one row per family
# ------------------------------------------------------------------------------
# The file has one row per person. SPM variables are identical for every
# person in the same family unit. SPM_HEAD == 1 flags one person per family
# (the reference person), so filtering to head gives one row per family.

dt <- dt[head == 1]


# ------------------------------------------------------------------------------
# Step 3: Remove invalid rows
# ------------------------------------------------------------------------------
# A zero or negative threshold can't be used as a denominator.
# These are rare edge cases

dt <- dt[threshold > 0]


# ------------------------------------------------------------------------------
# Step 4: Compute the adequacy ratio for each family unit
# ------------------------------------------------------------------------------

dt[, adequacy := resources / threshold]


# ------------------------------------------------------------------------------
# Step 5: Sort families from lowest to highest adequacy
# ------------------------------------------------------------------------------
# This orders the full population from worst-off to best-off.

setorder(dt, adequacy)

# ------------------------------------------------------------------------------
# Step 6: Compute each family's position in the weighted distribution
# ------------------------------------------------------------------------------
# Each row has a weight = how many real US families this survey row represents.
# Summing weights cumulatively tells us: what share of all US families have
# an adequacy ratio at or below this row's value?

total_weight <- sum(as.numeric(dt$weight))
dt[, cum_share := cumsum(as.numeric(weight)) / total_weight]

# ------------------------------------------------------------------------------
# Step 7: Read off the 20th, 50th, and 80th percentiles
# ------------------------------------------------------------------------------
# The Nth percentile is the adequacy ratio of the first family whose
# cumulative share reaches N%. That family sits right at that point
# in the distribution.

p20 <- dt[cum_share >= 0.20, adequacy][1]
p50 <- dt[cum_share >= 0.50, adequacy][1]
p80 <- dt[cum_share >= 0.80, adequacy][1]

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------

cat("SPM family units in file: ", format(nrow(dt), big.mark = ","), "\n\n")

cat("SPM adequacy ratio at selected percentiles\n")
cat("(1.00 = exactly at the family's poverty threshold)\n\n")
cat("  20th percentile:", round(p20, 4), "\n")
cat("  50th percentile:", round(p50, 4), "\n")
cat("  80th percentile:", round(p80, 4), "\n")
