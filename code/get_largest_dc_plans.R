## Setup
library(dplyr)
library(tidyr)
library(zoo)
library(lubridate)

## Load in Data
data_filled <- read.csv("./data/raw_dc_dodge_data_new.csv")

large_plans <- data_filled %>%
  filter(proj_phase == 1) %>%
  mutate(date = as.Date(date)) %>%
  group_by(ReportID) %>%
  arrange(ReportID, desc(date)) %>%
  slice(1) %>% 
  filter(ProjectValue >= 10000 & is.na(YearRmvd)) %>%
  select(ReportID, Title, date, ProjectValue, targetdate, StateProvince, PostalCode) %>%
  rename(ReportDate = date, TargetStartDate = targetdate) %>%
  mutate(ReportDate = as.yearmon(ReportDate)) %>%
  arrange(-ProjectValue) %>%
  mutate(ProjectValue = ProjectValue/1000)
  
write.csv(large_plans, "./data/dc_plans_value_ten_billion.csv", row.names = FALSE)
