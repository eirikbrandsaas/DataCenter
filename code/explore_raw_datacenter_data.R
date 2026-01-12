## Read in Data
# Jan2003_m <- read.csv("/mcr/hbs_data/dodge/data/SupplyTrack_History_2003_To_2015_csvs/ProjectMaster.csv")
# Jan2016_m <- read.csv("/mcr/hbs_data/dodge/data/SupplyTrack_History_2016_To_Apr23_csvs/ProjectMaster.csv")
# May2023_m <- read.csv("/mcr/hbs_data/dodge/data/REA_May-Nov_2023_csvs/ProjectMaster.csv")
# Dec2023_m <- read.csv("/mcr/hbs_data/dodge/data/REA_122023_csvs/ProjectMaster.csv")
# 
# Jan2003_h <- read.csv("/mcr/hbs_data/dodge/data/SupplyTrack_History_2003_To_2015_csvs/ProjectHistory.csv")
# Jan2016_h <- read.csv("/mcr/hbs_data/dodge/data/SupplyTrack_History_2016_To_Apr23_csvs/ProjectHistory.csv")
# May2023_h <- read.csv("/mcr/hbs_data/dodge/data/REA_May-Nov_2023_csvs/ProjectHistory.csv")
# Dec2023_h <- read.csv("/mcr/hbs_data/dodge/data/REA_122023_csvs/ProjectHistory.csv")
# 
# Jan2003 <- merge(Jan2003_h, Jan2003_m, by = "ReportID")

# filepaths

require(fame)
require(tidyverse)
require(data.table)
require(janitor)
require(zoo)
require(lubridate)
require(sf)

dir_in = '/mcr/hbs_data/dodge/data/' # data path
dir_out = '/mcr/hbs_data/dodge/code/rea/' # data path

new.dirs = str_subset(list.dirs(dir_in), '[0-9]_csvs') # use regex to pull relevant dirs
dirs_dates = str_extract(new.dirs, '[0-9]+') %>% as.yearmon(format = "%m%Y") # use regex to get months
dirs_by_date = tibble(dir = new.dirs, date = dirs_dates) %>% # make it into a tibble for sorting
  mutate(date = case_when(dir=="/mcr/hbs_data/dodge/data//REA_May-Nov_2023_csvs" ~ as.yearmon('May 2023'), # manually set the historical data
                          dir=="/mcr/hbs_data/dodge/data//SupplyTrack_History_2016_To_Apr23_csvs" ~ as.yearmon('Jan 2016'),
                          dir=="/mcr/hbs_data/dodge/data//SupplyTrack_History_2003_To_2015_csvs" ~ as.yearmon('Jan 2003'),
                          TRUE ~ date)) %>% # make sure the rest stays!
  arrange(-date) # arrange in reverse historical order
dirs_by_date <- dirs_by_date[21:23,]
last_date = dirs_by_date$date[[1]]
history_dirs = dirs_by_date$dir
history_dirs_dates = dirs_by_date$date

states_in = '/mcr/hbs_data/dodge/code/manuf/state/cb_2018_us_state_20m.shp'
state_pop = '/mcr/hbs_data/dodge/code/manuf/state/state_pop.csv'

# Define global variables
canada_provinces <- c("AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT")

process_directory <- function(dir, date) {
 # Initialize removed_reports as NULL
  removed_reports <- NULL
  
  # Check if RemovedReports.csv exists
  if (file.exists(paste0(dir, '/RemovedReports.csv'))) {
    removed_reports <- read.csv(file = paste0(dir, '/RemovedReports.csv'))
    removed_repid <- unique(removed_reports$ReportID)
  }
  
  # Read ProjectMaster.csv
  ProjectMaster.csv <- read.csv(file = paste0(dir, '/ProjectMaster.csv'))
  
  # Filter and process ProjectMaster.csv
  office_df <- ProjectMaster.csv %>%
    filter(PropertyTypeID == 3) %>%
    select(ReportID, RepNum, Title, StateProvince, PostalCode, PropertyTypeID, IsMasterProject, 
           SubPropertyTypeID, BuildingAreaSF, ProjectValue, TargetStartDate, TargetCompletionDate, 
           TargetOpenDate, IsActiveFlag) %>%
    filter(!(StateProvince %in% canada_provinces)) %>%
    mutate(RepNum = as.character(RepNum), 
           ReportID = as.character(ReportID),
           date_dir = date)
  
  # Read and process ProjectHistory.csv
  ProjectHistory.csv <- read_csv(paste0(dir, '/ProjectHistory.csv')) %>%
    mutate(ReportID = as.character(ReportID), 
           RepNum = as.character(RepNum),
           date_dir = date)
  
  history_df <- ProjectHistory.csv %>%
    filter(ReportID %in% office_df$ReportID)
  
  # Merge datasets
  merged_df <- merge(history_df, office_df, by = c('ReportID', 'date_dir'), all.x = TRUE)
  
  merged_df <- merged_df %>% 
    fill(Title, StateProvince, PostalCode, PropertyTypeID, BuildingAreaSF, 
         ProjectValue, TargetStartDate, TargetOpenDate, IsActiveFlag, IsMasterProject)
  
  # Process phases
  key_plan <- c(1, 2, 3, 4)
  key_build <- c(5, 6, 7)
  key_abandoned <- c(8, 9)
  
  merged_df <- merged_df %>%
    mutate(
      proj_phase = case_when(
        PhaseID %in% key_plan ~ 1,
        PhaseID %in% key_build ~ 6,
        PhaseID %in% key_abandoned ~ 9,
        TRUE ~ NA_real_
      ),
      date = yearmon(YearNumber + (MonthNumber - 1) / 12),
      targetdate = as.yearmon(TargetStartDate, '%m/%d/%y'),
      is_data_center = ifelse(SubPropertyTypeID == 68, 1, 0)
    )

  # Process removed reports only if they exist
  if (!is.null(removed_reports)) {
    removed_reports <- removed_reports %>%
      mutate(removed_date = yearmon(YearNumber + (MonthNumber - 1) / 12)) %>% 
      select(ReportID, removed_date)
    
    merged_df <- merge(merged_df, removed_reports, by = 'ReportID', all.x = TRUE)
  } else {
    # If no removed reports, add an empty removed_date column
    merged_df$removed_date <- NA
  }
  
  merged_df <- merge(merged_df, removed_reports, by = 'ReportID', all.x = TRUE)
  
  return(merged_df)
}

# Process all directories
all_results <- Map(process_directory, dirs_by_date$dir, dirs_by_date$date)

# Combine all results
final_merged_df <- do.call(rbind, all_results) %>%
  mutate(date = paste0(YearNumber, MonthNumber))

# Save the final merged dataset
saveRDS(final_merged_df, file = paste0(dir_out, 'office_merged_df_correc.rds'))