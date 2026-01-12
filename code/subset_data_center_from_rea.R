## Setup
library(dplyr)
library(lubridate)
library(tidyr)
library(readr)
library(purrr)
library(fs)
library(here)

all_directories <- c(directories_to_search, old_directories)

# Get Subset of Data Centers
# process each directory
fn_process_directory <- function(directory) {
  cat("Processing directory:", directory, "\n")
  
  # find files
  project_master_path <- file.path(directory, "ProjectMaster.csv")
  master_child_path <- file.path(directory, "ProjectMasterChild.csv")
  
  # check if both files exist
  if (file.exists(project_master_path) && file.exists(master_child_path)) {
    # read the files
    tryCatch({
      project_master <- read_csv(project_master_path, show_col_types = FALSE) %>%
        select(ReportID, SubPropertyTypeID) %>%
        filter(SubPropertyTypeID == 68)
      master_child <- read_csv(master_child_path, show_col_types = FALSE) %>%
        select(MasterReportID, ChildReportID) %>%
        rename(ReportID = ChildReportID)
      
      # merge the files by ReportID
      merged_data <- left_join(project_master, master_child, by = "ReportID")
      
      # add source directory info
      merged_data$source_directory <- directory
      
      cat("  Successfully processed", nrow(merged_data), "rows\n")
      return(merged_data)
    }, error = function(e) {
      cat("  Error processing files:", conditionMessage(e), "\n")
      return(NULL)
    })
  } else {
    cat("  Required files not found in this directory\n")
    return(NULL)
  }
}

# process all directories and combine results
master_child_dc <- map(all_directories, fn_process_directory) %>%
  bind_rows()

# create xwalk between master reports and child reports
xwalk_master_child <- master_child_dc %>%
  distinct(ReportID, MasterReportID, .keep_all = TRUE) %>%
  select(ReportID, MasterReportID, source_directory)

# pull ReportIDs relevant to project
dc_parent_repids <- na.omit(xwalk_master_child$MasterReportID)
dc_child_repids <- xwalk_master_child$ReportID
dc_repids_all <- unique(c(dc_parent_repids, dc_child_repids))

# save xwalk and repids
saveRDS(xwalk_master_child, here("data", "master_child_xwalk_dc.rds"))
saveRDS(dc_repids_all, here("data", "dc_repids.rds"))

