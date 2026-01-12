## Setup
library(dplyr)
library(readr)
library(zoo)
library(lubridate)
library(purrr)
library(fs)
library(tidyr)
library(here)

## Specify Search Directories
# create a function to extract the directory name
fn_extract_dir_name <- function(path) {
  parts <- strsplit(path, "_")[[1]]
  if (grepl("May-Nov", path)) {
    return("052023")}
  else if (grepl("REA", path)) {
    return(paste0(substr(parts[length(parts)-1], 1, 6)))
  }  
  else if (grepl("2016_To_Apr23", path)) {
    return("012016")
  } else if (grepl("2003_To_2015", path)) {
    return("012003")
  }
}

# read in reportids from data centers and data center parents projects
repids <- readRDS(here("data", "dc_repids.rds"))

# create the dataframes
old_dirs <- data.frame(
  dir = old_directories,
  dir_name = sapply(old_directories, fn_extract_dir_name)
)

dirs_by_date <- data.frame(
  dir = directories_to_search,
  dir_name = sapply(directories_to_search, fn_extract_dir_name)
)

row.names(dirs_by_date) <- NULL

rmvd_reports <- read.csv(paste0(dirs_by_date$dir[1], "/RemovedReports.csv"))

# Function to process a single directory
process_directory <- function(dir, dir_name) {
  tryCatch({
    # Read MasterProject.csv
    masters_path <- file.path(dir, "ProjectMaster.csv")
    masters <- read_csv(masters_path) %>%
      select(ReportID, RepNum, Title, StateProvince, PostalCode, City, Address, PropertyTypeID, 
             IsMasterProject, SubPropertyTypeID, ProjectValue,
             TargetStartDate, TargetCompletionDate, TargetOpenDate, IsActiveFlag, CountyID) %>%
      filter(ReportID %in% repids)
    
    # Read ProjectHistory.csv
    history_path <- file.path(dir, "ProjectHistory.csv")
    history <- read_csv(history_path) %>%
      filter(ReportID %in% repids)
    
    # Add RepNum column to history if it doesn't exist
    if (!"RepNum" %in% names(history)) {
      history <- history %>% mutate(RepNum = NA)
    }
    
    # Merge masters and history
    master_history <- left_join(history, masters, by = "ReportID") %>%
      mutate(dir_name = dir_name) %>%
      mutate(proj_phase = case_when(
        PhaseID %in% c(1,2,3,4) ~ 1,
        PhaseID %in% c(6,7) ~ 6,
        PhaseID %in% c(8,9) ~ 9,
        TRUE ~ 0
      ),
      date = yearmon(YearNumber+(MonthNumber-1)/12),
      targetdate = as.yearmon(TargetStartDate,'%m/%d/%y'),
      is_data_center = if_else(SubPropertyTypeID == 68, 1, 0))  %>%
      filter(!(StateProvince %in% c('BC','ON','QC','SK','AB','NS','MB','PE','NF','NB','NT','NU',"YT")))
    
    # Print a message to track progress
    cat("Processed directory:", dir, "with dir_name:", dir_name, "\n")
    
    return(master_history)
    
  }, error = function(e) {
    # If there's an error, print it and continue to the next directory
    cat("Error processing directory:", dir, "with dir_name:", dir_name, "\n")
    cat("Error message:", conditionMessage(e), "\n")
    return(NULL)
  })
}

## Run Data Load
# Apply the function to each row using lapply
all_data <- lapply(seq_len(nrow(dirs_by_date)), function(i) {
  process_directory(dirs_by_date$dir[i], dirs_by_date$dir_name[i])
})

# Remove NULL results (from errors)
all_data <- all_data[!sapply(all_data, is.null)]

# Combine all the data frames
rea <- bind_rows(all_data)

rea_rmvd <- rea %>%
  left_join(rmvd_reports, by = "ReportID") %>%
  mutate(Notes = if_else(grepl("DUPLICATE REPORT", Notes), "DUPLICATE REPORT", Notes),
         Notes = if_else(grepl("Master Report :All projects have been broken away", Notes), "Master Report :All projects have been broken away)", Notes))


saveRDS(rea_rmvd, here("data", "dc_rea_post_052023.rds"))

# Print the dimensions of the final dataset
cat("Final dataset dimensions:", dim(rea_rmvd), "\n")

## Run Manually for Oldest Directories
dir <- old_dirs[1,]$dir
dir_name <- old_dirs[1,]$dir_name

# Read MasterProject.csv
masters_path <- file.path(dir, "ProjectMaster.csv")
masters <- read_csv(masters_path) %>%
  select(ReportID, RepNum, Title, StateProvince, PostalCode, City, Address, PropertyTypeID, 
         IsMasterProject, SubPropertyTypeID, ProjectValue,
         TargetStartDate, TargetCompletionDate, TargetOpenDate, IsActiveFlag, CountyID) %>%
  filter(ReportID %in% repids)

# Read ProjectHistory.csv
history_path <- file.path(dir, "ProjectHistory.csv")
history <- read_csv(history_path) %>%
  filter(ReportID %in% repids)

# Add RepNum column to history if it doesn't exist
if (!"RepNum" %in% names(history)) {
  history <- history %>% mutate(RepNum = NA)
}

# Merge masters and history
rea <- left_join(history, masters, by = "ReportID") %>%
  mutate(dir_name = dir_name) %>%
  mutate(proj_phase = case_when(
    PhaseID %in% c(1,2,3,4) ~ 1,
    PhaseID %in% c(6,7) ~ 6,
    PhaseID %in% c(8,9) ~ 9,
    TRUE ~ 0
  ),
  date = yearmon(YearNumber+(MonthNumber-1)/12),
  targetdate = as.yearmon(TargetStartDate,'%m/%d/%y'),
  is_data_center = if_else(SubPropertyTypeID == 68, 1, 0))  %>%
  filter(!(StateProvince %in% c('BC','ON','QC','SK','AB','NS','MB','PE','NF','NB','NT','NU',"YT")))

rea_rmvd <- rea %>%
  left_join(rmvd_reports, by = "ReportID") %>%
  mutate(Notes = if_else(grepl("DUPLICATE REPORT", Notes), "DUPLICATE REPORT", Notes),
         Notes = if_else(grepl("Master Report :All projects have been broken away", Notes), "Master Report :All projects have been broken away)", Notes))

    
saveRDS(rea_rmvd, here("data", "dc_rea_2016_042023.rds"))

## Pre 2016 Data
dir <- old_dirs[2,]$dir
dir_name <- old_dirs[2,]$dir_name

# Read MasterProject.csv
masters_path <- file.path(dir, "ProjectMaster.csv")
masters <- read_csv(masters_path) %>%
  select(ReportID, RepNum, Title, StateProvince, PostalCode, City, Address, PropertyTypeID, 
         IsMasterProject, SubPropertyTypeID, ProjectValue,
         TargetStartDate, TargetCompletionDate, TargetOpenDate, IsActiveFlag, CountyID) %>%
  filter(ReportID %in% repids)

# Read ProjectHistory.csv
history_path <- file.path(dir, "ProjectHistory.csv")
history <- read_csv(history_path) %>%
  filter(ReportID %in% repids)

# Add RepNum column to history if it doesn't exist
if (!"RepNum" %in% names(history)) {
  history <- history %>% mutate(RepNum = NA)
}

# Merge masters and history
rea <- left_join(history, masters, by = "ReportID") %>%
  mutate(dir_name = dir_name) %>%
  mutate(proj_phase = case_when(
    PhaseID %in% c(1,2,3,4) ~ 1,
    PhaseID %in% c(6,7) ~ 6,
    PhaseID %in% c(8,9) ~ 9,
    TRUE ~ 0
  ),
  date = yearmon(YearNumber+(MonthNumber-1)/12),
  targetdate = as.yearmon(TargetStartDate,'%m/%d/%y'),
  is_data_center = if_else(SubPropertyTypeID == 68, 1, 0))  %>%
  filter(!(StateProvince %in% c('BC','ON','QC','SK','AB','NS','MB','PE','NF','NB','NT','NU',"YT")))

rea_rmvd <- rea %>%
  left_join(rmvd_reports, by = "ReportID") %>%
  mutate(Notes = if_else(grepl("DUPLICATE REPORT", Notes), "DUPLICATE REPORT", Notes),
         Notes = if_else(grepl("Master Report :All projects have been broken away", Notes), "Master Report :All projects have been broken away)", Notes))

saveRDS(rea_rmvd, here("data", "dc_rea_2003_2015.rds"))
    
