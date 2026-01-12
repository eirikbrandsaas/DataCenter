********************************************************************************
* File: simulation.do
* Purpose: Run main Monte Carlo simulations
********************************************************************************

* Loop through scenarios: 0 = baseline, 1 = bust, 2 = constant, 3 = boom
forv scenario = 0/3 {
	global scenario   = `scenario'
	global input_data "data/data_center_project_level_scenario$scenario.dta"

	****************************************************************************
	* Step 0: Create dataset of stock in planning, by cohort of planning entry
	****************************************************************************
	
	use $input_data, clear
	set seed $seed
	keep if inplanning == 1

	* Collapse to total value by planning entry month
	keep repnum value_plan date_plan

	save data/active_plans.dta, replace

	****************************************************************************
	* Step 1: Draw random simulation parameters
	****************************************************************************
	

	* Load parameters
	use data/parameters.dta, clear
	local cancel_mean      = cancellation_rate[1]
	local cancel_se        = cancellation_rate_se[1]
	local time_mean        = time_to_start[1]
	local time_se          = time_to_start_se[1]
	local compl_const_mean = compl_const[1]
	local compl_const_se   = compl_const_se[1]
	local compl_coef_mean  = compl_coef[1]
	local compl_coef_se    = compl_coef_se[1]

	* Draw simulation parameters
	clear
	set obs $sims

	gen sim_id        = _n
	gen cancel_rate   = .
	gen time_to_start = .
	gen compl_const   = .
	gen compl_coef    = .

	forvalues s = 1/$sims {
	    * Cancellation rate (bounded between 0 and 1)
	    local cancel_draw = rnormal(`cancel_mean', `cancel_se')
	    replace cancel_rate = max(0, min(1, `cancel_draw')) in `s'
	    
	    * Time to start (cannot be negative)
	    local time_draw = rnormal(`time_mean', `time_se')
	    replace time_to_start = max(0, `time_draw') in `s'
	    
	    * Draw completion regression parameters
	    replace compl_const = rnormal(`compl_const_mean', `compl_const_se') in `s'
	    replace compl_coef  = rnormal(`compl_coef_mean', `compl_coef_se')   in `s'
	}

	save data/simulation_parameters.dta, replace
	
	****************************************************************************
	* Step 2: Calculate start dates and proceeding values for each simulation
	****************************************************************************
	

	* Initialize empty dataset to store results
	clear
	gen date_plan   = .
	gen value_plan  = .
	gen sim_id      = .
	gen start_month = .

	save data/simulation_starts.dta, replace

	* Loop through each simulation
	qui forvalues s = 1/$sims {
	    noi display "Simulation `s'"
	    
	    * Load parameters for this simulation
	    use data/simulation_parameters.dta, clear
	    local cancel_s = cancel_rate[`s']
	    local time_s   = time_to_start[`s']
	    local const_s  = compl_const[`s']
	    local coef_s   = compl_coef[`s']

	    * Load planning stock data
	    use data/active_plans.dta, clear

	    * Randomly cancel projects
	    gen random_draw = runiform()
	    drop if random_draw < `cancel_s'
	    
	    * Calculate start month and proceeding value
	    gen start_month = date_plan + round(`time_s')
	    gen sim_id      = `s'
	    format start_month %tm
	    
	    * Save this simulation to its own tempfile
	    tempfile sim`s'
	    save `sim`s''
	}

	* Append all simulations at once
	use `sim1', clear
	forvalues s = 2/$sims {
	    append using `sim`s''
	}

	save data/simulation_starts.dta, replace

	****************************************************************************
	* Step 3: Apply phase-in matrix to spread investment over duration
	****************************************************************************
	

	use data/simulation_starts.dta, clear
	merge m:1 sim_id using data/simulation_parameters.dta, keepusing(compl_const compl_coef)
	drop _merge
	gen duration = round(compl_const + compl_coef * log(value_plan))
	replace duration = max(1, duration)

	* Expand each observation by its specific duration
	expand duration
	bysort repnum sim_id: gen phase_month      = _n - 1
	gen investment_month = start_month + phase_month

	bysort repnum sim_id: gen investment = value_plan / duration
	keep sim_id date_plan investment_month investment repnum
	save data/simulation_investment.dta, replace

	****************************************************************************
	* Step 4: Aggregate investment by month for each simulation
	****************************************************************************
	

	use data/simulation_investment.dta, clear
	collapse (sum) total_investment = investment, by(investment_month sim_id)
	sort sim_id investment_month
	save data/simulation_results.dta, replace

	****************************************************************************
	* Step 5: Prepare started projects to be included later
	****************************************************************************
	

	use $input_data
	keep if !missing(date_start)
	keep repnum value_start date_start

	* Expand for each simulation
	expand $sims
	bysort repnum: gen sim_id = _n

	* Merge in simulation-specific completion parameters
	merge m:1 sim_id using data/simulation_parameters.dta, keepusing(compl_const compl_coef)
	drop _merge

	* Calculate project-specific completion time
	gen duration = round(compl_const + compl_coef * log(value_start))
	replace duration = max(1, duration)

	* Expand and calculate investment
	expand duration
	bysort repnum sim_id: gen phase_month    = _n - 1
	gen investment_month = date_start + phase_month

	gen investment = value_start / duration
	keep repnum sim_id investment_month investment

	collapse (sum) started_investment = investment, by(investment_month sim_id)
	sort sim_id investment_month
	format investment_month %tm

	save data/started_investment.dta, replace

	****************************************************************************
	* Step 6: Merge results
	****************************************************************************
	
	use data/simulation_results.dta, clear
	merge 1:1 investment_month sim_id using "data/started_investment.dta"
	replace started_investment = 0 if missing(started_investment)

	rename total_investment plan_investment
	gen total_investment = plan_investment + started_investment

	* Aggregate investment within quarters for each simulation
	gen investment_quarter = qofd(dofm(investment_month))
	format investment_quarter %tq

	gen scenario = $scenario
	save data/simulation_results_scenario$scenario.dta, replace
}

********************************************************************************
