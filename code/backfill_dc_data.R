## Setup
library(dplyr)
library(tidyr)
library(zoo)
library(lubridate)
library(here)

# load in office data and subset to data centers
dcpre2016 <- readRDS(here("data", "dc_rea_2003_2015.rds"))
dc2016apr2023 <- readRDS(here("data", "dc_rea_2016_042023.rds"))
dcmay2023present <- readRDS(here("data", "dc_rea_post_052023.rds"))

# combine and correct phases
data <- rbind(dcpre2016, dc2016apr2023, dcmay2023present) %>%
  select(-RepNum.y, -RepNum) %>%
  rename(YearRmvd = YearNumber.y, MonthRmvd = MonthNumber.y, RepNum = RepNum.x, YearNumber = YearNumber.x, MonthNumber = MonthNumber.x) %>%
  mutate(proj_phase = case_when(
    PhaseID %in% c(1,2,3,4) ~ 1,
    PhaseID %in% c(6,7) ~ 6,
    PhaseID %in% c(8,9) ~ 9,
    TRUE ~ 0
  ))

# front fill data between updates
data_filled <- data %>%
  mutate(date = as.Date(date)) %>%
  # group by ReportID
  group_by(ReportID) %>%
  # arrange by date within each group
  arrange(date) %>%
  # create a complete sequence of dates for each ReportID
  complete(date = seq(min(date), max(date), by = "month")) %>%
  # fill missing values forward
  fill(everything(), .direction = "down") %>%
  # ungroup to remove grouping
  ungroup()

# remove duplicate reports
data_filled <- data_filled %>%
  filter(!grepl("duplicate report", Notes, ignore.case = TRUE))

# save csv
write.csv(data_filled, here("data", "raw_dc_dodge_data_new.csv"), row.names = FALSE)
