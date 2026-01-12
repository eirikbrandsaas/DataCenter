library(dplyr)
library(zoo)
library(lubridate)

## Load in Data
data <- readRDS("./data/data_center_panel.rds") %>%
  mutate(targetstart = as.Date(as.yearmon(targetstart)))

microdata <- readRDS('/mcr/hbs_data/dodge/code/rea/office_starts_sum.rds')

starts <- data %>%
  filter(proj_phase == 6) %>%
  group_by(repnum) %>%
  arrange(desc(date)) %>%
  slice(1) %>%
  group_by(targetstart) %>%
  summarise(start_value = sum(value))

sum_starts_year <- microdata %>%
  mutate(year = year(as.Date(targetdate))) %>%
  group_by(year) %>%
  summarise(sum_start_value = sum(dc_value)/1000)

write.csv(sum_starts_year, "./data/packet_dc_starts_valuesum.csv")

## New Plans By Year
plns_by_yr <- data %>%
  filter(proj_phase == 1) %>%
  group_by(repnum) %>%
  arrange(repnum, date) %>%
  slice(1) %>%
  ungroup() %>%
  group_by(year(date)) %>%
  summarise(new_plan_value = sum(value))
