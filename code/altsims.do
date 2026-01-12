********************************************************************************
* File: altsims.do
* Purpose: Create alternative simulation scenarios
********************************************************************************

global lowyear  2024
global highyear 2025

********************************************************************************
* Step 1: Calculate baseline statistics from historical period
********************************************************************************
use data/data_center_project_level.dta, clear
keep if inrange(year(dofm(date_plan)), $lowyear, $highyear)

* Calculate monthly statistics
gen month = date_plan
collapse (count) n_projects = repnum (sum) total_value = value_plan, by(month)

* Get average monthly count and value
sum n_projects
global avg_count = round(r(mean))
sum total_value
global avg_value = round(r(mean))

display "Average monthly count: $avg_count projects"
display "Average monthly value: $avg_value"

file open texfile using "figures/stats.tex", write append
file write texfile "\newcommand{\Nprojmonth}{$avg_count}" _n
file write texfile "\newcommand{\projvalmonth}{$avg_value}" _n
file write texfile "\newcommand{\altsimlowyear}{$lowyear}" _n
file write texfile "\newcommand{\altsimhiyear}{$highyear}" _n
file close texfile

********************************************************************************
* Step 2: Determine time horizon
********************************************************************************
use data/data_center_project_level.dta, clear
sum date_plan
local fill_start = `r(max)' + 1
local fill_end   = tm(2026m12)  // TODO: Automate this based on forecast horizon
local months_to_fill = `fill_end' - `fill_start' + 1

display "Filling from `fill_start' to `fill_end' (`months_to_fill' months)"

********************************************************************************
* Step 3: Get max repnum for creating unique IDs
********************************************************************************

sum repnum
local max_repnum = r(max)

********************************************************************************
* Step 4: Create scenario datasets
********************************************************************************

use data/data_center_project_level.dta, clear
save data/data_center_project_level_scenario0.dta, replace


* Create scenarios 1-3: Bust, Constant, Boom
qui forvalues scen = 1/3 {
    * Set scenario-specific value multiplier
    if `scen' == 1 {
        local multiplier  = 0.25
        local scen_name   = "bust"
    }
    else if `scen' == 2 {
        local multiplier  = 1.0
        local scen_name   = "constant"
    }
    else {
        local multiplier  = 2.0
        local scen_name   = "boom"
    }
    
    local target_value  = $avg_value * `multiplier'
    local project_value = `target_value' / $avg_count
    
    noi display "Creating scenario `scen' (`scen_name'): `multiplier'x value"
    noi display "  Target monthly value: `target_value'"
    noi display "  Value per project: `project_value'"
    noi display "  Projects per month: $avg_count"
    
    * Start with baseline data
    use data/data_center_project_level.dta, clear
    tempfile scenario_data
    save `scenario_data'
    
    * Track repnum counter
    local repnum_counter = `max_repnum' + 1
    
    * Loop through each future month
    local fill_month = `fill_start'
    
    forvalues m = 1/`months_to_fill' {
        clear
        set obs $avg_count
        
        * Create synthetic projects
        gen double repnum = `repnum_counter' + _n - 1
        format repnum %9.0f
        gen value_plan    = `project_value'
        gen date_plan     = `fill_month'
        gen date_start    = .
        gen date_complete = .
        gen inplanning    = 1
        gen started       = 0
        gen completed     = 0
        gen cancelled     = 0
        
        * Append to baseline
        append using `scenario_data'
        save `scenario_data', replace
        
        * Update counters
        local repnum_counter = `repnum_counter' + $avg_count
        local fill_month     = `fill_month' + 1
    }
    
    * Save scenario dataset
    use `scenario_data', clear
    save data/data_center_project_level_scenario`scen'.dta, replace
    
    * Display summary
    count if date_plan >= `fill_start' & !missing(date_plan)
    local expected = $avg_count * `months_to_fill'
    noi display "Scenario `scen' (`scen_name'): Created `r(N)' synthetic projects (expected: `expected')"
}

display "Scenario datasets created successfully!"
display "Average count: $avg_count"
display "Average value: $avg_value"

********************************************************************************
