library(here)
library(dplyr)

### SET DIRECTORIES
## Find Dodge Data Directories
data_dir <- "/mcr/hbs_data/dodge/data" # folder where dodge data is located 
pattern <- "REA_([0-9]{6})_csvs$"
directories_dates <- data.frame(dir = character(), date = character(), stringsAsFactors = FALSE)
all_dirs <- list.dirs(data_dir, full.names = TRUE, recursive = FALSE)

# loop through all directories
for (directory in all_dirs) {

  folder_name <- basename(directory)

  match <- regexpr(pattern, folder_name, perl = TRUE)
  
  if (match != -1) {
    
    date_string <- regmatches(folder_name, regexec(pattern, folder_name))[[1]][2]

    directories_dates <- rbind(directories_dates, data.frame(dir = directory, date_string = date_string, stringsAsFactors = FALSE))
  }
}

# make variable for the corresponding date and order descending by date
directories_dates <- directories_dates %>%
  mutate(date = as.Date(paste0(substr(date_string, 3, 6), "-",  substr(date_string, 1, 2), "-", "01"))) %>%
  arrange(desc(date))

late_2023 <- c("/mcr/hbs_data/dodge/data/REA_May-Nov_2023_csvs", "052023", "2023-05-01")
directories_dates <- rbind(directories_dates, late_2023)

# place just the directories into a vector
old_directories <- c(
  "/mcr/hbs_data/dodge/data/SupplyTrack_History_2016_To_Apr23_csvs",
  "/mcr/hbs_data/dodge/data/SupplyTrack_History_2003_To_2015_csvs"
)


# denote start vintage for iteration
start_vintage <- "2025-01-01"
start_vintage_index <- which(directories_dates$date == as.Date(start_vintage)) - 1

### RUN R SCRIPTS

for (i in 0:start_vintage_index) {
  
  subdirectories <- directories_dates[(i+1):(nrow(directories_dates)), ]
  directories_to_search <- subdirectories$dir
  vintage_suffix <- subdirectories$date_string[1]
  
  ## Core Data Creation
  # get ReportIDs for all data center projects and their master reports -- saves a lot of computational time
  source(here("code", "subset_data_center_from_rea.R"))
  # get full history of data for all relevant ReportIDs
  source(here("code", "clean_raw_rea.R"))
  # fill in gaps in data between updates
  source(here("code", "backfill_dc_data.R"))
  # clean data center data -- phase work, etc.
  source(here("code", "get_cleaned_dc_rea_data.R"))
  # combine master reports with their child reports
  source(here("code", "merge_master_reports.R"))
}

## Save start and end dates
dates <- c(directories_dates$date_string[start_vintage_index + 1], directories_dates$date_string[1])
write.csv(dates, here("data", "vintage_start_end_dates.csv"), row.names = FALSE)
