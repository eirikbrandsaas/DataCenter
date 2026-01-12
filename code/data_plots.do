********************************************************************************
* File: data_plots.do
* Purpose: Create plots of data center project data
********************************************************************************

********************************************************************************
* Plot: Time to start distribution
********************************************************************************

use data/data_center_project_level.dta, clear
keep if !missing(time_plan_to_start)

* Calculate total value by time to start
collapse (sum) total_value = value_plan, by(time_plan_to_start)

* Sort and calculate cumulative percentage
sort time_plan_to_start

gen cum_value  = sum(total_value)
gen total      = cum_value[_N]
gen cum_share  = cum_value / total * 100

twoway line cum_share time_plan_to_start, ///
    ytitle("Cumulative % of Project Value Started", size(large)) ///
    xtitle("Months from Plan to Start", size(large)) ///
    title("Time to Start Distribution (Value-Weighted)", size(large)) ///
    xlabel(0(50)150, labsize(large)) ///
    ylabel(0(20)100, labsize(large)) ///
    lwidth(medthick) ///
    lcolor($linecolor) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/time_to_start_CDF.pdf", replace
graph export "figures/vintages/time_to_start_CDF_$vintage_str.png", replace
export delimited cum_share time_plan_to_start using figures/508_figS2.csv, replace

* Find share of plans that become starts within that period
sum cum_share if time_plan_to_start <= $maxtimeplan
local timetostartmaxplan = round(`r(max)')
file open texfile using "figures/stats.tex", write append
file write texfile "\newcommand{\timetostartmaxplan}{`timetostartmaxplan'}" _n
file close texfile

********************************************************************************
* Plot: Flow of new plans
********************************************************************************

use data/data_center_project_level.dta, clear
collapse (sum) value_* (mean) cancelled started, by(date_plan)
keep if yofd(dofm(date_plan)) > 2021

twoway line value_plan date_plan, ///
    ytitle("Billions of Dollars", size(large)) ///
    xtitle("", size(large)) ///
    xlabel(`=ym(2022,1)'(12)`=ym(2026,1)', format(%tmCCYY) labsize(large)) ///
    ylabel(0(150)600, labsize(large)) ///
    lwidth(medthick) ///
    lcolor($linecolor) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/plan_value_over_time.pdf", replace
graph export "figures/vintages/plan_value_over_time_$vintage_str.png", replace
export delimited value_plan date_plan using figures/508_fig2_left.csv, replace

********************************************************************************
* Plot: Starts over time
********************************************************************************

use data/data_center_project_level.dta, clear
keep if started == 1
keep repnum value_start date_start
collapse (sum) value_start, by(date_start)
gen year = year(dofm(date_start))
keep if year > 2021

twoway line value_start date_start, ///
    lcolor($linecolor) ///
    lwidth(medthick) ///
    ytitle("Billions of Dollars", size(large)) ///
    xtitle("Date", size(large)) ///
    xlabel(, format(%tmCY) labsize(large)) ///
    ylabel(, labsize(large)) ///
    title("Data Center Construction Starts Over Time", size(large)) ///
    note("Source: Authors' analysis of Dodge Analytics Data", size(medium)) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/starts_over_time.pdf", replace

********************************************************************************
* Plot: Planning stock count
********************************************************************************

use data/data_center_panel, clear

* Keep only projects in planning phase
keep if proj_phase_desc == "plan"

* Collapse to monthly totals
collapse (count) planning_stock_count = value (sum) planning_stock_value = value, by(date)
keep if yofd(dofm(date)) > 2021

* Plot count
twoway line planning_stock_count date, ///
    ytitle("Number of Projects in Planning", size(large)) ///
    xtitle("Year", size(large)) ///
    title("Planning Stock Counts", size(large)) ///
    xlabel(, format(%tmCCYY) labsize(large)) ///
    ylabel(, labsize(large)) ///
    lwidth(medthick) ///
    lcolor($linecolor) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/planning_stock_count.pdf", replace

********************************************************************************
* Plot: Planning stock value
********************************************************************************

twoway line planning_stock_value date, ///
    ytitle("Billions of Dollars", size(large)) ///
    xlabel(`=ym(2022,1)'(12)`=ym(2026,1)', format(%tmCCYY) labsize(large)) ///
    xtitle("", size(large)) ///
    ylabel(0(500)1500, labsize(large)) ///
    lwidth(medthick) ///
    lcolor($linecolor) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/planning_stock_value.pdf", replace
graph export "figures/vintages/planning_stock_value_$vintage_str.png", replace
export delimited planning_stock_value date using figures/508_fig2_right.csv, replace

********************************************************************************
