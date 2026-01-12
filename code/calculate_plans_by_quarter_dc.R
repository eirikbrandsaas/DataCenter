## Setup
library(dplyr)
library(purrr)
library(readr)
library(lubridate)
library(zoo)

## Read in Data
data <- readRDS('/mcr/hbs_data/dodge/code/rea/office_rea_data_unfilled_new.rds') %>%
  filter(SubPropertyTypeID == 68) %>%
  filter(ReportID != 803586) # no phase updates in 8 years

## Data Manipulations
# convert data to quarterly
data_q <- data %>%
  mutate(date = as.yearqtr(date))

# calculate bottom up plans
plans_data <- data_q %>%
  filter(proj_phase == 1) %>%
  filter(!grepl("Stargate | Kestrel | Jupiter", Title, ignore.case = TRUE)) %>%
  group_by(ReportID) %>%
  arrange(ReportID, date) %>%
  slice(1)

plans_data_mega <- data_q %>%
  filter(proj_phase == 1) %>%
  filter(grepl("Stargate | Kestrel | Jupiter", Title, ignore.case = TRUE)) %>%
  group_by(ReportID) %>%
  arrange(ReportID, date) %>%
  slice(1)

plans_sum <- plans_data %>%
  group_by(date) %>% 
  summarise(value = sum(ProjectValue)/1000) %>%
  filter(date >= 2022) %>%
  mutate(date = as.Date(date)) %>%
  mutate(name = "Non-Mega Projects") %>%
  select(date, name, value)

plans_mega_sum <- plans_data_mega %>%
  group_by(date) %>% 
  summarise(value = sum(ProjectValue)/1000) %>%
  filter(date >= 2022) %>%
  mutate(date = as.Date(date)) %>%
  mutate(name = "Mega") %>%
  select(date, name, value)

plans_sum <- rbind(plans_sum, plans_mega_sum)

write.csv(plans_sum, "./data/data_center_plans_sum.csv", row.names = FALSE)
