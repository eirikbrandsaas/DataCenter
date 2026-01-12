## Setup
library(dplyr)
library(tidyr)
library(zoo)
library(lubridate)

## Load in Data
data_master <- read.csv("./data/data_center_panel_with_masters.csv") 

data <- read.csv("./data/data_center_panel.csv")

### TIME BETWEEN PHASES ANALYSIS
## Plan to Start
# filter to only projects that have plan and start where plan precedes start and project does not end with abandoned
pts <- data %>%
  group_by(repnum) %>%
  filter(any(proj_phase == 6) & any(proj_phase == 1)) %>%
  filter(max(date[proj_phase == 6]) > max(date[proj_phase == 1]) &
           last(proj_phase != 9))

pts_comp <- pts %>%
  group_by(repnum) %>%
  mutate(phase_change = proj_phase != lag(proj_phase, default = first(proj_phase))) %>%
  filter((proj_phase == 1 & row_number() == min(row_number()[proj_phase == 1])) | 
           (proj_phase == 6 & phase_change & row_number() == max(row_number()[proj_phase == 6 & phase_change]))) %>%
  ungroup()

pts_result <- pts_comp %>%
  group_by(repnum) %>%
  summarise(months_pts = interval(first(date), last(date)) %/% months(1))

months_pts <- mean(pts_result$months_pts)

## Plan to Cancellation
ptc <- data %>%
  group_by(repnum) %>%
  filter(any(proj_phase == 9) & any(proj_phase == 1)) %>%
  filter(max(date[proj_phase == 9]) > max(date[proj_phase == 1]) &
           last(proj_phase == 9))

ptc_comp <- ptc %>%
  group_by(repnum) %>%
  mutate(phase_change = proj_phase != lag(proj_phase, default = first(proj_phase))) %>%
  filter((proj_phase == 1 & row_number() == min(row_number()[proj_phase == 1])) | 
           (proj_phase == 9 & phase_change & row_number() == max(row_number()[proj_phase == 9 & phase_change]))) %>%
  ungroup()

ptc_result <- ptc_comp %>%
  group_by(repnum) %>%
  summarise(months_ptc = interval(first(date), last(date)) %/% months(1))

months_ptc <- mean(ptc_result$months_ptc)

### RATES ANALYSIS
roc <- data %>%
  group_by(repnum) %>%
  filter(any(proj_phase == 1)) %>%
  mutate(canceled = if_else(any(proj_phase == 9) & any(proj_phase == 1) & max(date[proj_phase == 9]) > max(date[proj_phase == 1]) &
           last(proj_phase == 9), 1, 0)) %>%
  slice(1) %>%
  ungroup() %>%
  mutate(canceled_adjusted = canceled * value / sum(value))

mean(roc$canceled)
sum(roc$canceled_adjusted)
