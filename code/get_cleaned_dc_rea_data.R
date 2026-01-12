## Setup
library(dplyr)
library(tidyr)
library(zoo)
library(lubridate)
library(here)

## Load in Data
data_filled <- read.csv(here("data", "raw_dc_dodge_data_new.csv"))

# correct completion date
data_compl <- data_filled %>%
  group_by(ReportID) %>%
  mutate(
    date_entry = as.Date(date, frac = 0),
    compldate = as.Date(strptime(TargetCompletionDate, format = "%m/%d/%y %H:%M:%S")),
    compldate = last(compldate, order_by = date_entry),  # Set compldate to the last reported value
    proj_phase = case_when(
      date_entry >= compldate ~ 7,
      TRUE ~ proj_phase
    )
  ) %>%
  ungroup()

## Clean Data
# function to convert decimal date
data_clean <- data_compl %>%
  select(ReportID, Title, StateProvince, PostalCode, ProjectValue, proj_phase, targetdate, compldate, date, MonthNumber, YearNumber, SubPropertyTypeID)

colnames(data_clean) <- c("repnum","title", "state_abbr", "zipcode", "value", "proj_phase", "targetstart", "completiondate","date", "month", "year", "proj_type")

data_final <- data_clean %>%
  select(repnum, date, title, proj_phase, value, targetstart, completiondate, state_abbr, zipcode, proj_type) %>%
  arrange(repnum, date)

data_final_newphase <- data_final %>%
  group_by(repnum) %>%
  mutate(
    # find the latest transition to start and make everything before it a plan
    last_start_transition = max(which(proj_phase == 6 & lag(proj_phase != 6, default = TRUE))),
    proj_phase_new = if_else(row_number() < last_start_transition, 1, proj_phase),

    # find the latest transition to plan and make everything before it a plan
    last_plan_transition = max(which(proj_phase == 1 & lag(proj_phase != 1, default = TRUE))),
    proj_phase_new = if_else(row_number() < last_plan_transition, 1, proj_phase_new),

    # handle projects that end in complete (7) and adjust canceled (9) phases
    ends_complete = last(proj_phase_new) == 7,
    prev_non_canceled = case_when(
      proj_phase_new != 9 ~ proj_phase_new,
      TRUE ~ NA_real_
    ),
    prev_non_canceled = na.locf(prev_non_canceled, na.rm = FALSE),
    proj_phase_new = case_when(
      ends_complete & proj_phase_new == 9 & prev_non_canceled == 1 ~ 1,
      ends_complete & proj_phase_new == 9 & prev_non_canceled == 6 ~ 6,
      TRUE ~ proj_phase_new
    )
  ) %>%
  select(-last_start_transition, -last_plan_transition, -ends_complete, -prev_non_canceled) %>%
  ungroup()

abandon_date <- max(as.Date(data_final_newphase$date)) - years(3)

# if project ended with plan and has not been updated in 3 years, switch last entry to abandoned
data_final_newphase <- data_final_newphase %>%
  group_by(repnum) %>%
  arrange(repnum, date) %>%
  mutate(proj_phase_new = if_else(date == max(date) & date <= as.Date(abandon_date) & proj_phase_new == 1, 9, proj_phase_new)) %>%
  ungroup() %>%
  mutate(proj_phase_desc_new = case_when(
    proj_phase_new == 1 ~ "plan",
    proj_phase_new == 6 ~ "start",
    proj_phase_new == 7 ~ "complete",
    proj_phase_new == 9 ~ "abandoned/deferred",
    TRUE ~ NA),
    proj_phase_desc = case_when(
      proj_phase == 1 ~ "plan",
      proj_phase == 6 ~ "start",
      proj_phase == 7 ~ "complete",
      proj_phase == 9 ~ "abandoned/deferred",
      TRUE ~ NA))

## Check Every Transition
transitions <- data_final_newphase %>%
  group_by(repnum) %>%
  arrange(date) %>%
  mutate(
    invalid_transition = case_when(
      lag(proj_phase_new) == 6 & proj_phase_new == 1 ~ TRUE,
      lag(proj_phase_new) == 7 & proj_phase_new %in% c(1, 6, 9) ~ TRUE,
      lag(proj_phase_new) == 9 & proj_phase_new %in% c(1, 6, 7) ~ TRUE,
      proj_phase_new < lag(proj_phase_new) & !is.na(lag(proj_phase_new)) ~ TRUE,
      TRUE ~ FALSE
    ),
    valid_transition = !any(invalid_transition, na.rm = TRUE)
  ) %>%
  ungroup()

# if TRUE, then all transitions are as expecteded
all(transitions$valid_transition)

data_final_newphase <- data_final_newphase %>%
  select(repnum, date, title, proj_phase_new, proj_phase_desc_new, value, targetstart, completiondate, state_abbr,
         zipcode, proj_phase, proj_phase_desc, proj_type)

colnames(data_final_newphase) <- c("repnum", "date", "title","proj_phase", "proj_phase_desc",  "value", "targetstart", "targetcompletion", "state_abbr",
                                   "zipcode", "proj_phase_old", "proj_phase_desc_old", "proj_type")

saveRDS(data_final_newphase, here("data", "dc_data_phase_cleaned_unmerged_masters.rds"))



