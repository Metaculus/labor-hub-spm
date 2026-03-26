# 04_visualize.R
# Produces trend charts and summary tables from the batch run output.
# Run after 03_batch_run.R has completed.

library(data.table)
library(ggplot2)

OUTPUT_DIR <- "results"
results    <- fread(file.path(OUTPUT_DIR, "spm_adequacy_by_percentile.csv"))
results[, percentile := factor(percentile, levels = c(20, 50, 80),
                                labels = c("20th", "50th", "80th"))]

# ---------------------------------------------------------------------------
# Structural break annotations
# ---------------------------------------------------------------------------

breaks <- data.table(
  ref_year = c(2020, 2021),
  label    = c("COVID\nfield limits", "ARPA\nspike"),
  y_pos    = c(Inf, Inf)
)

# ---------------------------------------------------------------------------
# Main trend chart
# ---------------------------------------------------------------------------

p <- ggplot(results, aes(x = ref_year, y = adequacy_ratio,
                          color = percentile, group = percentile)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  geom_hline(yintercept = 1, linetype = "dotted", color = "grey40", linewidth = 0.7) +
  geom_vline(data = breaks, aes(xintercept = ref_year),
             linetype = "dashed", color = "grey60", linewidth = 0.5, inherit.aes = FALSE) +
  geom_text(data = breaks, aes(x = ref_year, y = Inf, label = label),
            vjust = 1.4, hjust = -0.1, size = 2.8, color = "grey40", inherit.aes = FALSE) +
  scale_color_manual(
    values = c("20th" = "#d7191c", "50th" = "#2c7bb6", "80th" = "#1a9641"),
    name   = "Adequacy\npercentile"
  ) +
  scale_x_continuous(breaks = 2018:2024) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.01)) +
  labs(
    title    = "SPM Adequacy Ratio by Adequacy Percentile, 2018–2024",
    subtitle = "Exact weighted 20th/50th/80th percentile of SPM_Resources / SPM_PovThreshold\nUnits ranked by adequacy ratio (adjusts for family size and geography). Dotted line = poverty threshold (ratio = 1.0)",
    x        = "Income year",
    y        = "Adequacy ratio (resources / threshold)",
    caption  = paste0(
      "Source: Census CPS ASEC public-use microdata with embedded SPM variables, income years 2018–2024.\n",
      "Dashed lines indicate structural breaks; ARPA spike (2021) is a policy artifact."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(size = 9, color = "grey40"),
    plot.caption  = element_text(size = 7.5, color = "grey50"),
    legend.position = "right"
  )

ggsave(file.path(OUTPUT_DIR, "spm_adequacy_trend.png"), p,
       width = 11, height = 6.5, dpi = 150)
message("Saved: ", file.path(OUTPUT_DIR, "spm_adequacy_trend.png"))

# ---------------------------------------------------------------------------
# Print wide summary table
# ---------------------------------------------------------------------------

wide <- fread(file.path(OUTPUT_DIR, "spm_adequacy_summary_wide.csv"))
message("\n=== SPM Adequacy Ratio Summary ===")
message("(Exact weighted percentile of adequacy ratio; 1.00 = exactly at SPM threshold)\n")
print(wide)
