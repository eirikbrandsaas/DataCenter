********************************************************************************
* File: analysis.do
* Purpose: Calculate key parameters and summary statistics
********************************************************************************

********************************************************************************
* Block 1: Use project-level to find time to start and cancellation rate
********************************************************************************

use data/data_center_project_level.dta, clear

count
local preest_sample_size = `r(N)'

* Year of date_plan for projects with date_plan not missing
gen year_plan = year(dofm(date_plan))

* Get statistics for 2025
su value_plan if year_plan == 2025, de
scalar countrecent   = r(N)
scalar meanrecent    = r(mean)
scalar medianrecent  = 1000 * r(p50)

* Get statistics for 2019-2022
su value_plan if inrange(year_plan, 2019, 2022), de
scalar countpre   = r(N)
scalar meanpre    = 1000 * r(mean)
scalar medianpre  = 1000 * r(p50)

* Only keep plans that have had a phase transition
keep if date_plan != .
keep if completed == 1 | started == 1 | cancelled == 1
keep if master_merged == 0

* Keep track of how many observations are dropped
count
local sample_size_dropest = round((1 - `r(N)' / `preest_sample_size') * 100)
display `sample_size_dropest'
file open texfile using "figures/stats.tex", write append
file write texfile "\newcommand{\samplesizedropest}{`sample_size_dropest'}" _n
file close texfile

* Calculate mean parameters
mean cancelled
scalar cancellation_rate    = _b[cancelled]
scalar cancellation_rate_se = _se[cancelled]

mean time_plan_to_start
scalar time_to_start    = _b[time_plan_to_start]
scalar time_to_start_se = _se[time_plan_to_start]

mean time_start_to_compl
scalar time_to_compl    = _b[time_start_to_compl]
scalar time_to_compl_se = _se[time_start_to_compl]

* Set variable labels
label var cancelled           "Fraction abandoned"
label var time_plan_to_start  "Months plan to start"
label var time_start_to_compl "Months start to compl"
label var value_plan          "Value in billions"

* Create summary statistics table for all projects
estpost tabstat cancelled time_plan_to_start time_start_to_compl value_plan, ///
    statistics(mean sd p10 p50 p90 count) columns(statistics)

* Export summary statistics table
esttab using "figures/summary_statistics_all.tex", replace ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p10(fmt(%9.2f)) p50(fmt(%9.2f)) p90(fmt(%9.2f)) count(fmt(%9.0f))") ///
    f nomtitles nonumbers noobs label collabels(none) nolines ///
    substitute("Fraction abandoned" "Fraction abandoned ({\$\lambda\$})" ///
               "Months plan to start" "Months plan to start ({\$T_{P,S}\$})" ///
               "Months start to compl" "Months start to compl ({\$T_{S,C}\$})" ///
               "Value in billions" "Value in billions ({\$V\$})")

* Calculate statistics for large plans (threshold > 0.25)
estpost tabstat cancelled time_plan_to_start time_start_to_compl value_plan if value_plan > 0.25, ///
    statistics(mean sd p10 p50 p90 count) columns(statistics)

* Export summary statistics for large projects
esttab using "figures/summary_statistics_big.tex", replace ///
    cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p10(fmt(%9.2f)) p50(fmt(%9.2f)) p90(fmt(%9.2f)) count(fmt(%9.0f))") ///
    f nomtitles nonumbers noobs label collabels(none) nolines ///
    substitute("Fraction abandoned" "Fraction abandoned ({\$\lambda\$})" ///
               "Months plan to start" "Months plan to start ({\$T_{P,S}\$})" ///
               "Months start to compl" "Months start to compl ({\$T_{S,C}\$})" ///
               "Value in billions" "Value in billions ({\$V\$})")

* Estimate completion time as function of project value
cap drop lvalue
gen lvalue = log(value_plan)
reg time_start_to_compl lvalue

scalar time_to_compl_cons    = _b[_cons]
scalar time_to_compl_cons_se = _se[_cons]
scalar time_to_compl_coef    = _b[lvalue]
scalar time_to_compl_coef_se = _se[lvalue]

********************************************************************************
* Block 2: Find stock of plans
********************************************************************************

use data/data_center_panel, clear

* Keep only projects in planning phase
keep if proj_phase_desc == "plan"
collapse (sum) value, by(date)
sum date
sum value if date == `r(max)', det
scalar planstock_value = `r(sum)'

********************************************************************************
* Block 3: Export results
********************************************************************************

clear
set obs 1

gen planstock_value      = planstock_value
gen time_to_start        = scalar(time_to_start)
gen time_to_start_se     = scalar(time_to_start_se)
gen cancellation_rate    = scalar(cancellation_rate)
gen cancellation_rate_se = scalar(cancellation_rate_se)
gen compl_const          = time_to_compl_cons
gen compl_const_se       = time_to_compl_cons_se
gen compl_coef           = time_to_compl_coef
gen compl_coef_se        = time_to_compl_coef_se

save data/parameters.dta, replace

* Round parameters for LaTeX export
local cancelrate     = round(scalar(cancellation_rate), 0.01)
local cancelrate_se  = round(scalar(cancellation_rate_se), 0.01)
local timetostart    = round(scalar(time_to_start), 0.01)
local timetostart_se = round(scalar(time_to_start_se), 0.01)
local complconst     = round(time_to_compl_cons, 0.01)
local complconst_se  = round(time_to_compl_cons_se, 0.01)
local complcoef      = round(time_to_compl_coef, 0.01)
local complcoef_se   = round(time_to_compl_coef_se, 0.01)
local countrecent    = string(round(countrecent), "%12.0f")
local meanrecent     = string(round(meanrecent), "%12.0f")
local medianrecent   = string(round(medianrecent), "%12.0f")
local countpre       = string(round(countpre), "%12.0f")
local meanpre        = string(round(meanpre), "%12.0f")
local medianpre      = string(round(medianpre), "%12.0f")

* Write parameters to LaTeX file
file open texfile using "figures/stats.tex", write append
file write texfile "\newcommand{\cancelrate}{`cancelrate'}" _n
file write texfile "\newcommand{\cancelratese}{`cancelrate_se'}" _n
file write texfile "\newcommand{\timetostart}{`timetostart'}" _n
file write texfile "\newcommand{\timetostartse}{`timetostart_se'}" _n
file write texfile "\newcommand{\complconst}{`complconst'}" _n
file write texfile "\newcommand{\complconstse}{`complconst_se'}" _n
file write texfile "\newcommand{\complcoef}{`complcoef'}" _n
file write texfile "\newcommand{\complcoefse}{`complcoef_se'}" _n
file write texfile "\newcommand{\countrecent}{`countrecent'}" _n
file write texfile "\newcommand{\meanrecent}{`meanrecent'}" _n
file write texfile "\newcommand{\medianrecent}{`medianrecent'}" _n
file write texfile "\newcommand{\countpre}{`countpre'}" _n
file write texfile "\newcommand{\meanpre}{`meanpre'}" _n
file write texfile "\newcommand{\medianpre}{`medianpre'}" _n
file close texfile

********************************************************************************
