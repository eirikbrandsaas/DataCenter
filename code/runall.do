********************************************************************************
* File: runall.do
* Purpose: Master do-file to run all project code
********************************************************************************

* Set working directory
cd "/mcr/hbs_data/dodge/res_data_center"


** Get vintages (stored in R-script). MMYYYY of first and last vintage.
import delimited "data/vintage_start_end_dates.csv", clear varnames(1) stringcols(1)
global vinm1 = substr(x[1], 1, 2) // Month of first vintage 
global viny1 = substr(x[1], 3, 4) // Year of of first vintage
global vinm2 = substr(x[_N], 1, 2) // Month of last vintage
global viny2 = substr(x[_N], 3, 4) // Year of of first vintage
global vin_start = monthly("${viny1}m${vinm1}", "YM") // Convert to monthly values
global vin_end   = monthly("${viny2}m${vinm2}", "YM")

* Note, if you are running code manually, you have to set the month and year 
* you want to use and 
// global y = 2025
// global m = 11

forv _v = $vin_start/$vin_end {
	* Extract year and month from monthly value
	local _y = year(dofm(`_v'))
	local _m = month(dofm(`_v'))
    
	global y = `_y'
	global m = `_m'
	
	do "code/convert_vintage_strings.do" Manipulate the strings

	* Set up globals and project settings
 	do "code/globals.do"
	
	* Load and clean data
	do "code/load_data.do"
	do "code/BEA_data.do"
	
	* Export global settings to LaTeX file

	* Analysis and plots
	do "code/analysis.do"
	do "code/data_plots.do"

	* Simulation
	do "code/altsims.do"      // Create data for alternative simulations
	do "code/simulation.do"   // Run Monte Carlo simulations
	do "code/plot_sims.do"    // Plot simulation results
	
}
}
********************************************************************************

