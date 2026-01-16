********************************************************************************
* File: load_data.do
* Purpose: Load and clean data center panel data
********************************************************************************

* Load the data center panel CSV
import delimited "data/data_center_panel_${M}${Y}.csv", clear

* Count observations to describe data cleaning
preserve
count
local total_obs = r(N)
bysort repnum: keep if _n == 1
count
local nunique_pre = r(N)
local ntimes_pre = round(`total_obs'/`nunique_pre')
restore

* Convert date strings to Stata date format
gen date_daily           = date(date, "YMD")
gen date_stata           = mofd(date_daily)
format date_stata %tm
drop date date_daily
rename date_stata date

gen targetstart_daily    = date(targetstart, "YMD")
gen targetstart_stata    = mofd(targetstart_daily)
format targetstart_stata %tm
drop targetstart targetstart_daily
rename targetstart_stata targetstart

* Set panel structure
xtset repnum date
sort repnum date

* Rename for simplicity
replace proj_phase_desc = "cancelled" if proj_phase_desc == "abandoned/deferred"

* Label projects as cancelled if they have been in planning for more than X months
by repnum: egen plan_duration = total(proj_phase_desc == "plan")
by repnum: gen last_phase      = proj_phase_desc[_N]
gen _cancelled = (plan_duration > $maxtimeplan & inlist(last_phase, "plan", "cancelled"))
bys repnum: gen _age = _n
replace proj_phase_desc = "cancelled" if _age > $maxtimeplan & _cancelled == 1
replace proj_phase      = 9            if _age > $maxtimeplan & _cancelled == 1
drop _cancelled _age

* Create transition variables
gen Lproj_phase = L.proj_phase
bys repnum: replace Lproj_phase = 0 if missing(Lproj_phase) & _n == 1
label define phase_lbl 0 "entry" 1 "plan" 6 "start" 7 "complete" 9 "cancelled"
label values proj_phase phase_lbl
label values Lproj_phase phase_lbl

* Order variables nicely
order repnum date title proj_phase proj_phase_desc value targetstart state_abbr zipcode
compress

replace value = value / 1000
label var value "Value (Billions)"

* Sample selection: Drop all projects that have any missing months (gaps in time series)
bysort repnum: egen has_gap = max(missing(Lproj_phase))
assert has_gap == 0
drop if has_gap == 1
drop has_gap

save data/data_center_panel.dta, replace

********************************************************************************
* Create project-level dataset
********************************************************************************

use data/data_center_panel, clear

* Collapse to project-level dataset with key phase dates
keep repnum date proj_phase_desc value master_merged

* Save values first ever recorded, or last-recorded (per stage)
bysort repnum proj_phase_desc (date): gen lastvalue  = value[_N]
bysort repnum proj_phase_desc (date): gen firstvalue = value[1]

* Only keep first occurence of each phase per project
* This keeps the first date per stage (first date plan was recorded, start was recorded, etc.)
* which we need to calculate time plan-to-start and start-to-complete
bysort repnum proj_phase_desc (date): keep if _n == 1

* Now decide which value to keep as main first value
* Default is first recorded because of _n == 1
replace value = lastvalue

* Reshape to wide format (one row per project)
reshape wide date value lastvalue firstvalue, i(repnum) j(proj_phase_desc) string

* Rename for clarity
rename date*       date_*
rename value*      value_*
rename lastvalue*  lastvalue_*
rename firstvalue* firstvalue_*

* Calculate time variables
gen time_plan_to_start  = date_start - date_plan if !missing(date_plan) & !missing(date_start) & missing(date_cancelled)
gen time_start_to_compl = date_complete - date_start if !missing(date_complete) & !missing(date_start) & missing(date_cancelled)

* Create easy-to-use project stage variables
gen cancelled  = !missing(date_cancelled)
gen started    = !missing(date_start)
gen completed  = !missing(date_complete)
gen inplanning = !missing(date_plan) & started == 0 & cancelled == 0 & completed == 0

save "data/data_center_project_level", replace

* Write to LaTeX file
file open texfile using "figures/stats.tex", write append
file write texfile "\newcommand{\Nobspostcleaning}{`nunique_pre'}" _n
file write texfile "\newcommand{\Ntimespostcleaning}{`ntimes_pre'}" _n
file close texfile
