## Setup
library(magick)
library(here)

################################################################################
# Script: create_vintage_gif.R
# Purpose: Create animated GIFs from vintage forecast PNGs
################################################################################

# Define figure patterns to process
figure_patterns <- c(
  "plan_value_over_time",
  "planning_stock_value",
  "simulation_mean_bands_quarter_hist",
  "simulation_scenarios_comparison",
  "simulation_scenarios_gdp_contr",
  "time_to_start_CDF",
  "total_investment_CDF",
  "total_investment_hist"
)

# Function to create a GIF for a given figure pattern
create_vintage_gif <- function(pattern, output_name) {
  
  cat("\n========================================\n")
  cat("Processing pattern:", pattern, "\n")
  cat("========================================\n")
  
  # Find all vintage PNG files for this pattern
  vintage_files <- list.files(
    path = here("figures", "vintages"),
    pattern = paste0(pattern, "_.*\\.png$"),
    full.names = TRUE
  )
  
  if (length(vintage_files) == 0) {
    stop(paste("No vintage PNG files found for pattern:", pattern))
  }
  
  cat("Found", length(vintage_files), "vintage files\n")
  
  # Extract dates from filenames and sort chronologically
  # Pattern: <figure_name>_2025m1.png -> 2025m1
  dates <- gsub(".*_(\\d{4}m\\d+)\\.png$", "\\1", basename(vintage_files))
  
  # Parse year and month for proper numerical sorting
  # This ensures m10, m11, m12 come after m9, not after m2
  year <- as.numeric(substr(dates, 1, 4))
  month <- as.numeric(gsub(".*m(\\d+)$", "\\1", dates))
  
  # Sort by year then month numerically
  sorted_idx <- order(year, month)
  vintage_files_sorted <- vintage_files[sorted_idx]
  dates_sorted <- dates[sorted_idx]
  
  cat("Processing vintages:", paste(dates_sorted, collapse = ", "), "\n")
  
  # Read all images
  cat("Reading images...\n")
  images <- image_read(vintage_files_sorted)
  
  # Add white space at the bottom for citation
  cat("Adding white space for citation...\n")
  images <- image_border(images, "white", "0x40")  # Add 40 pixels of white space at bottom
  
  # Add text labels to each frame showing the vintage date
  cat("Adding vintage labels...\n")
  images_labeled <- image_annotate(
    images,
    text = paste("Dodge Vintage:", dates_sorted),
    size = 20,
    color = "black",
    font = "Arial",
    weight = 700,
    location = "+90+20"
  )
  
  # Add citation note at the bottom
  cat("Adding citation note...\n")
  images_labeled <- image_annotate(
    images_labeled,
    text = 'See "Estimating Aggregate Data Center Investment with Project-level Data" by Brandsaas\n et al. for details. The views expressed in this paper are solely those of the  authors and do not\n necessarily reflect the opinions of the Federal Reserve Board or the Federal Reserve System.',
    size = 12,
    color = "black",
    font = "Arial",
    gravity = "south",
    location = "+0+10"
  )
  
  # Create animated GIF
  # fps = 5 means 5 frames per second = 0.2 seconds per frame
  cat("Creating animated GIF...\n")
  animation <- image_animate(images_labeled, delay = 33 )
  
  # Save GIF
  output_path <- here("figures", output_name)
  cat("Saving to:", output_path, "\n")
  image_write(
    animation,
    path = output_path
  )
  
  cat("GIF created successfully!\n")
  cat("Output:", output_path, "\n")
  cat("Total frames:", length(dates_sorted), "\n")
  cat("Duration:", length(dates_sorted) * 0.2, "seconds\n")
  
  return(output_path)
}

# Loop through each pattern and create GIFs
cat("\n########################################\n")
cat("CREATING VINTAGE GIFS\n")
cat("########################################\n")

for (pattern in figure_patterns) {
  output_name <- paste0(pattern, "_evolution.gif")
  create_vintage_gif(pattern = pattern, output_name = output_name)
}

cat("\n########################################\n")
cat("ALL GIFS CREATED SUCCESSFULLY!\n")
cat("########################################\n")
