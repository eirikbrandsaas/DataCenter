## Setup
library(dplyr)
library(readr)
library(zoo)
library(lubridate)
library(purrr)
library(fs)
library(tidyr)
library(here)

## Read in Data
master_child <- readRDS(here("data", "master_child_xwalk_dc.rds")) %>%
  filter(!is.na(MasterReportID)) %>%
  filter(ReportID != "45616") # remove problematic repnum that has multiple listed master reports
data_raw <- readRDS(here("data", "dc_data_phase_cleaned_unmerged_masters.rds")) %>%
  filter(repnum != "45616") # remove problematic repnum that has multiple listed master reports

## Merge in Master ReportID
data_master <- left_join(data_raw, master_child, by = c("repnum" = "ReportID"))
MasterRepIDs <- master_child %>% pull(MasterReportID)

# only keep master and child reports
to_merge <- data_master %>%
  filter(!is.na(MasterReportID) | repnum %in% MasterRepIDs) %>%
  mutate(MasterReportID = if_else(is.na(MasterReportID), repnum, MasterReportID)) %>%
  mutate(is_master = (repnum == MasterReportID)) %>%
  group_by(MasterReportID) %>%
  filter(any(is_master == 1) & n_distinct(repnum) > 1) %>%
  ungroup()

# perform manipulation of data to get just one entry per date per project -- merge children with their parents
child_merged_masters <- to_merge %>%
  mutate(date = as.Date(date)) %>%
  # group by MasterReportID
  group_by(MasterReportID) %>%
  group_modify(function(group_data, group_key) {
    # find master and child reports
    master_rows <- filter(group_data, is_master == 1)
    child_rows <- filter(group_data, is_master == 0)
    
    if (nrow(child_rows) == 0) {
      # no child reports, just return master rows
      return(master_rows)
    }
    
    # create a lookup for the most recent master value at each date
    master_values <- master_rows %>%
      arrange(date) %>%
      mutate(latest_master_value = value)
    
    # get the most recent master value for any date using a rolling join
    get_latest_master_value <- function(current_date) {
      previous_values <- filter(master_values, date <= current_date)
      if (nrow(previous_values) == 0) return(NA_real_)  # Return NA of type double
      idx <- which.max(previous_values$date)
      return(previous_values$latest_master_value[idx])  # Return the actual value, not a data frame subset
    }
    
    # find the first date when a child report appears
    first_child_date <- min(child_rows$date)
    
    # keep master rows only up to the first child date
    master_rows_to_keep <- filter(master_rows, date < first_child_date)
    
    # use child rows from the first child date onwards
    child_rows_to_use <- filter(child_rows, date >= first_child_date)
    
    # update child rows to use master values
    child_rows_to_use <- child_rows_to_use %>%
      rowwise() %>%
      mutate(value = get_latest_master_value(date)) %>%
      ungroup()
    
    # combine master and child rows and sort by date
    combined_rows <- bind_rows(master_rows_to_keep, child_rows_to_use) %>%
      arrange(date)
    
    # check for dates with terminal phases according to the new rules
    phase_transition <- child_rows_to_use %>%
      group_by(date) %>%
      summarize(
        # case 1: all children are complete
        all_phase_7 = all(proj_phase == 7) && n() == n_distinct(repnum),
        # case 2: all children are abandoned
        all_phase_9 = all(proj_phase == 9) && n() == n_distinct(repnum),
        # case 3: at least one child is complete AND all others are abandoned
        mixed_completion = any(proj_phase == 7) && all(proj_phase %in% c(7, 9)) && n() == n_distinct(repnum),
        .groups = "drop"
      ) %>%
      mutate(
        # If it's a mixed completion, it should be treated as a phase 7
        is_terminal = all_phase_7 | all_phase_9 | mixed_completion,
        terminal_phase = case_when(
          all_phase_7 ~ 7,
          mixed_completion ~ 7,  # Consider it complete if mix of complete and abandoned
          all_phase_9 ~ 9,
          TRUE ~ NA_real_
        )
      ) %>%
      filter(is_terminal) %>%
      arrange(date)
    
    # if we found dates with terminal phases
    if (nrow(phase_transition) > 0) {
      # get the first date where this happens
      first_transition <- phase_transition[1,]
      cutoff_date <- first_transition$date
      
      # get the terminal phase value
      phase_value <- first_transition$terminal_phase
      
      # update proj_phase:
      # - set to phase_value at cutoff_date
      # - set to 6 for any 7 or 9 values before cutoff_date
      # - leave other phases as they were
      combined_rows <- combined_rows %>%
        mutate(proj_phase = case_when(
          date >= cutoff_date ~ phase_value,
          date < cutoff_date & proj_phase %in% c(7, 9) ~ 6,  # Change only 7 or 9 to 6
          TRUE ~ proj_phase  # Keep other phases as they are
        )) %>%
        filter(date <= cutoff_date)
    }
    
    # add this part to ensure one row per date
    combined_rows <- combined_rows %>%
      group_by(date) %>%
      slice(1) %>%  # take the first row for each date
      ungroup()
    
    return(combined_rows)
  }) %>%
  ungroup()

# Bring datasets back together
merged_repids <- c(unique(child_merged_masters$repnum), unique(child_merged_masters$MasterReportID))

data_unmerged <- data_raw %>%
  filter(!(repnum %in% merged_repids))%>%
  mutate(master_merged = 0) %>%
  mutate(date = as.Date(date))

data_merged <- child_merged_masters %>%
  mutate(repnum = MasterReportID) %>%
  select(-MasterReportID, -source_directory, -is_master) %>%
  mutate(master_merged = 1)

data_final <- rbind(data_unmerged, data_merged) %>%
  group_by(repnum) %>%
  arrange(repnum, date) %>%
  filter(last(proj_type == 68)) %>%
  ungroup()

# redo phasework
data_final_newphase <- data_final %>%
  group_by(repnum) %>%
  mutate(
    # find the latest transition to start and make everything before it a plan
    last_start_transition = max(which(proj_phase == 6 & lag(proj_phase != 6, default = TRUE))),
    proj_phase = if_else(row_number() < last_start_transition, 1, proj_phase),
    
    # find the latest transition to plan and make everything before it a plan
    last_plan_transition = max(which(proj_phase == 1 & lag(proj_phase != 1, default = TRUE))),
    proj_phase = if_else(row_number() < last_plan_transition, 1, proj_phase),
    
    # handle projects that end in complete (7) and adjust canceled (9) phases
    ends_complete = last(proj_phase) == 7,
    prev_non_canceled = case_when(
      proj_phase != 9 ~ proj_phase,
      TRUE ~ NA_real_
    ),
    prev_non_canceled = na.locf(prev_non_canceled, na.rm = FALSE),
    proj_phase = case_when(
      ends_complete & proj_phase == 9 & prev_non_canceled == 1 ~ 1,
      ends_complete & proj_phase == 9 & prev_non_canceled == 6 ~ 6,
      TRUE ~ proj_phase
    )
  ) %>%
  mutate(proj_phase_desc = case_when(
    proj_phase == 1 ~ "plan",
    proj_phase == 6 ~ "start",
    proj_phase == 7 ~ "complete",
    proj_phase == 9 ~ "abandoned/deferred",
    TRUE ~ NA),
    proj_phase_desc = case_when(
      proj_phase == 1 ~ "plan",
      proj_phase == 6 ~ "start",
      proj_phase == 7 ~ "complete",
      proj_phase == 9 ~ "abandoned/deferred",
      TRUE ~ NA)) %>%
  select(-last_start_transition, -last_plan_transition, -ends_complete, -prev_non_canceled) %>%
  ungroup()

# backfill again to account for gaps between masters and children
data_filled <- data_final_newphase %>%
  mutate(date = as.Date(date)) %>%
  # group by ReportID
  group_by(repnum) %>%
  # arrange by date within each group
  arrange(date) %>%
  # create a complete sequence of dates for each ReportID
  complete(date = seq(min(date), max(date), by = "month")) %>%
  # fill missing values forward
  fill(everything(), .direction = "down") %>%
  # ungroup to remove grouping
  ungroup()

# do final cleaning steps
data_save <- data_filled %>%
  mutate(is_data_center = if_else(proj_type == 68, 1, 0)) %>%
  select(-proj_type) %>%
  filter(!is.na(value)) %>%
  group_by(repnum) %>%
  mutate(has_master_in_title = any(grepl("master rep", title, ignore.case = TRUE))) %>%
  ungroup() %>%
  mutate(master_merged = if_else(repnum %in% MasterRepIDs | has_master_in_title == 1, 1, master_merged)) %>%
  select(-has_master_in_title)

## Conduct Final Testing on Data Structure
# test for missing months of data
data_incomplete <- data_save %>%
  group_by(repnum) %>%
  summarise(
    distinct_months = n_distinct(floor_date(date, "month")),
    min_date = min(date),
    max_date = max(date),
    expected_months = length(seq(floor_date(min_date, "month"), 
                                 floor_date(max_date, "month"), 
                                 by = "month")),
    has_missing_months = distinct_months < expected_months
  ) %>%
  filter(has_missing_months)

nrow(data_incomplete)

# test for variables differing across repnum that should not
data_differing <- data_save %>%
  group_by(repnum) %>%
  filter(n_distinct(master_merged) > 1)
  
nrow(data_differing)

# test that all transitions are valid
transitions <- data_save %>%
  group_by(repnum) %>%
  arrange(date) %>%
  mutate(
    invalid_transition = case_when(
      lag(proj_phase) == 6 & proj_phase == 1 ~ TRUE,
      lag(proj_phase) == 7 & proj_phase %in% c(1, 6, 9) ~ TRUE,
      lag(proj_phase) == 9 & proj_phase %in% c(1, 6, 7) ~ TRUE,
      proj_phase < lag(proj_phase) & !is.na(lag(proj_phase)) ~ TRUE,
      TRUE ~ FALSE
    ),
    valid_transition = !any(invalid_transition, na.rm = TRUE)
  ) %>%
  ungroup()

all(transitions$valid_transition)

## Save Data
write.csv(data_save, here("data", "data_center_panel.csv"), row.names = FALSE)
write.csv(data_save, here("data", paste0("data_center_panel_", vintage_suffix, ".csv")), row.names = FALSE)
