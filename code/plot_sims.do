********************************************************************************
* File: plot_sims.do
* Purpose: Plot simulation results and create scenario comparisons
********************************************************************************

global scenario = 0

********************************************************************************
* Plot: Distribution of total investment
********************************************************************************

use data/simulation_results_scenario$scenario.dta, clear

* Calculate total investment for each simulation
collapse (sum) plan_investment, by(sim_id)

sum plan_investment, detail

histogram plan_investment, ///
    xtitle("Total Investment Value (Billions USD)", size(large)) ///
    ytitle("Density", size(large)) ///
    title("Distribution of Total Simulated Investment", size(large)) ///
    color($linecolor) ///
    bins(50) ///
    xlabel(0(300)1200, labsize(large)) ///
    ylabel(, labsize(large)) ///
    xline(`r(p50)', lpattern(dash) lcolor(black) lwidth(medthick)) ///
    xline(`r(mean)', lpattern(solid) lcolor(black) lwidth(medthick)) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/total_investment_hist.pdf", replace
graph export "figures/vintages/total_investment_hist_$vintage_str.png", replace

********************************************************************************
* Plot: CDF of total investment
********************************************************************************

cumul plan_investment, gen(cdf)
sum plan_investment, detail

twoway line cdf plan_investment, ///
    sort ///
    xtitle("Total Investment Value (Billions USD)", size(large)) ///
    ytitle("Cumulative Probability", size(large)) ///
    title("CDF of Total Simulated Investment", size(large)) ///
    lcolor($linecolor) ///
    lwidth(medthick) ///
    xlabel(0(300)1200, labsize(large)) ///
    ylabel(0(0.2)1.0, labsize(large)) ///
    xline(`r(p50)', lpattern(dash) lcolor(black) lwidth(medthick)) ///
    xline(`r(mean)', lpattern(solid) lcolor(black) lwidth(medthick)) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(5.28) ysize(4)
graph export "figures/total_investment_CDF.pdf", replace
graph export "figures/vintages/total_investment_CDF_$vintage_str.png", replace

replace plan_investment = round(plan_investment, 0.1)
compress
export delimited sim_id plan_investment cdf using figures/508_figS3.csv, replace

********************************************************************************
* Plot: Distribution and timing of investment (quarterly)
********************************************************************************

use data/simulation_results_scenario$scenario.dta, clear
collapse (sum) total_investment, by(investment_quarter sim_id)
rename investment_quarter time
gen investment_annl = total_investment * 4
gen year = year(dofq(time))
keep if year >= 2023

collapse (mean) mean_inv = investment_annl ///
         (min) min_inv = investment_annl ///
         (p1) p1_inv = investment_annl ///
         (p25) p25_inv = investment_annl ///
         (p75) p75_inv = investment_annl ///
         (p50) p50_inv = investment_annl ///
         (p5) p5_inv = investment_annl ///
         (p95) p95_inv = investment_annl ///
         (p99) p99_inv = investment_annl ///
         (max) max_inv = investment_annl, by(time)

keep if time < $forecast_qtr +1 

* Merge with historical data
gen year = yofd(dofq(time))
gen qtr  = quarter(dofq(time))
merge 1:1 year qtr using "data/inv_dc.dta", keepusing(inv_dc)
drop if _merge == 2

twoway (rarea min_inv max_inv time, color($color1)) ///
       (rarea p1_inv p99_inv time, color($color2)) ///
       (rarea p5_inv p95_inv time, color($color3)) ///
       (rarea p25_inv p75_inv time, color($color4)) ///
       (line mean_inv time, lcolor($linecolor) lpattern(solid) lwidth(medthick)) ///
       (line p50_inv time, lcolor($linecolor) lpattern(dash) lwidth(medthick)) ///
       (line inv_dc time, lcolor(red) lpattern(dash) lwidth(medthick)), ///
    ytitle("$ytitle", size(large)) ///
    xlabel(`=tq(2023q1)'(4)`=tq(2026q2)', labsize(large)) ///
    ylabel(0(100)500, labsize(large)) ///
    yscale(titlegap(5)) ///
    xtitle("", size(large)) ///
    legend(on order(5 "Mean" 6 "Median" 4 "25-75" 3 "5-95" 2 "1-99" 1 "Min-Max" 7 "Data") ///
           rows(1) pos(6) size(large) span) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(8) ysize(5)
graph export "figures/simulation_mean_bands_quarter_hist.pdf", replace
graph export "figures/vintages/simulation_mean_bands_quarter_hist_$vintage_str.png", replace


export delimited min_inv max_inv p1_inv p99_inv p5_inv p95_inv p25_inv p75_inv ///
    mean_inv p50_inv inv_dc time using figures/508_fig3top.csv, replace

********************************************************************************
* Plot: Combined scenarios comparison
********************************************************************************

* Load and combine all scenarios
clear
append using data/simulation_results_scenario0.dta
append using data/simulation_results_scenario1.dta
append using data/simulation_results_scenario2.dta
append using data/simulation_results_scenario3.dta

* First collapse: aggregate by quarter/simulation/scenario
collapse (sum) total_investment, by(investment_quarter sim_id scenario)
rename investment_quarter time
gen investment_annl = total_investment * 4
gen year = year(dofq(time))
save data/simulation_results_stacked.dta, replace

use data/simulation_results_stacked.dta, clear
keep if year >= 2025
keep if year <= 2027

* Second collapse: get mean and percentiles by quarter/scenario
collapse (mean) mean_inv = investment_annl ///
         (p5) plo_inv = investment_annl ///
         (p95) phi_inv = investment_annl, ///
         by(time scenario)

* Define colors
local color_baseline "navy"
local color_bust     "maroon"
local color_constant "gold"
local color_boom     "green"

* Plot all four scenarios
twoway ///
    (rarea plo_inv phi_inv time if scenario == 0 & time <=  $forecast_qtr + 1 , ///
        color(`color_baseline'%30)) ///
    (line mean_inv time if scenario == 0 & time <=  $forecast_qtr + 1 , ///
        lcolor(`color_baseline') lwidth(medthick) lpattern(solid)) ///
    (rarea plo_inv phi_inv time if scenario == 1 & time >=  $forecast_qtr + 1 , ///
        color(`color_bust'%15)) ///
    (line mean_inv time if scenario == 1 & time >=  $forecast_qtr + 1 , ///
        lcolor(`color_bust') lwidth(medthick) lpattern(solid)) ///
    (rarea plo_inv phi_inv time if scenario == 2 & time >=  $forecast_qtr + 1 , ///
        color(`color_constant'%30)) ///
    (line mean_inv time if scenario == 2 & time >=  $forecast_qtr + 1 , ///
        lcolor(`color_constant') lwidth(medthick) lpattern(solid)) ///
    (rarea plo_inv phi_inv time if scenario == 3 & time >= $forecast_qtr + 1, ///
        color(`color_boom'%10)) ///
    (line mean_inv time if scenario == 3 & time >= $forecast_qtr + 1, ///
        lcolor(`color_boom') lwidth(medthick) lpattern(solid)), ///
    ytitle("$ytitle", size(large)) ///
    xtitle("Quarter", size(large)) ///
    xlabel(`=tq(2025q1)'(4)`=tq(2027q4)', labsize(large)) ///
    ylabel(0(250)1250, labsize(large)) ///
    legend(order(2 "Short-run" 8 "Inflow 2x" 6 "Inflow 1x" 4 "Inflow 0.25x") ///
           rows(1) pos(6) size(large) span) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(8) ysize(5)
graph export "figures/simulation_scenarios_comparison.pdf", replace
graph export "figures/vintages/simulation_scenarios_comparison_$vintage_str.png", replace

export delimited plo_inv phi_inv mean_inv scenario time ///
    using figures/508_fig3bot.csv, replace

********************************************************************************
* GDP contributions analysis
********************************************************************************

* Create dataset of GDP numbers
clear
input int year float real_gdp float gdp_price float nominal_gdp nominal_gdp_level
2022  .    .    7.9  26771
2023  .    .    6.2  28424
2024  .    .    4.9  29825
2025  1.9  2.7  4.6  .
2026  1.8  2.6  4.4  .
2027  2.1  .    .    .
end

label variable year             "Year"
label variable real_gdp         "Real GDP (%, Chain Weighted)"
label variable gdp_price        "GDP Price Index (% Change)"
label variable nominal_gdp      "Nominal GDP (%)"
label variable nominal_gdp_level "Nominal GDP ($ Billions)"

tsset year

replace gdp_price = l.gdp_price if year == 2027
replace nominal_gdp = real_gdp + gdp_price if year >= 2027
replace nominal_gdp_level = L.nominal_gdp_level * (1 + nominal_gdp / 100) if missing(nominal_gdp_level)

tempfile gdp
save `gdp'

use data/simulation_results_stacked.dta, clear

collapse (mean) datacenter = investment_annl year, by(time scenario)
collapse (last) datacenter, by(year scenario)

keep if year >= 2021
merge m:1 year using `gdp', nogen

xtset scenario year

gen dc_share        = datacenter / nominal_gdp_level
gen dc_growth       = D.datacenter / L.datacenter * 100
gen dc_contr        = (datacenter - L.datacenter) / L.nominal_gdp_level * 100
gen dc_contr_imports = dc_contr * $importshare_datacenter

save data/simulation_results_stacked_wgdp, replace

********************************************************************************
* Plot: Contribution to GDP growth
********************************************************************************

use data/simulation_results_stacked_wgdp, clear

* Define colors
local color_baseline "navy"
local color_bust     "maroon"
local color_constant "gold"
local color_boom     "green"

keep if year >= 2023
keep if year < 2028

twoway ///
    (line dc_contr year if scenario == 0 & year <= 2025, ///
        lcolor(`color_baseline') lwidth(medthick) lpattern(solid)) ///
    (line dc_contr year if scenario == 1 & year >= 2025, ///
        lcolor(`color_bust') lwidth(medthick) lpattern(solid)) ///
    (line dc_contr year if scenario == 2 & year >= 2025, ///
        lcolor(`color_constant') lwidth(medthick) lpattern(solid)) ///
    (line dc_contr year if scenario == 3 & year >= 2025, ///
        lcolor(`color_boom') lwidth(medthick) lpattern(solid)), ///
    ytitle("Percentage Point", size(large)) ///
    xtitle("Year", size(large)) ///
    xlabel(, labsize(large)) ///
    ylabel(-1(0.5)2, labsize(large)) ///
    title("Contribution to GDP Growth Incl. Imported Inputs", size(large)) ///
    legend(order(1 "Short-run" 4 "Inflow 2x" 3 "Inflow 1x" 2 "Inflow 0.25x") ///
           rows(1) pos(6) size(large)) ///
    graphregion(color(white)) ///
    plotregion(margin(medium)) ///
    xsize(8) ysize(5)
graph export "figures/simulation_scenarios_gdp_contr.pdf", replace
graph export "figures/vintages/simulation_scenarios_gdp_contr_$vintage_str.png", replace

********************************************************************************
* Create LaTeX table
********************************************************************************

use data/simulation_results_stacked_wgdp, clear

* Keep only scenarios 1-3 and years 2023-2027
keep if inlist(scenario, 1, 2, 3)
keep if year >= 2023 & year <= 2027
keep year scenario dc_growth dc_contr datacenter dc_contr_imports

* Reshape to wide format
reshape wide dc_growth dc_contr dc_contr_imports datacenter, i(year) j(scenario)

* Sort by year
sort year

* Open file for writing
file open latex using "figures/dc_table.tex", write replace

* Write data rows
forvalues i = 1/`=_N' {
    local yr  = year[`i']
    local dg1 : display %6.0f datacenter1[`i']
    local dg2 : display %6.0f datacenter2[`i']
    local dg3 : display %6.0f datacenter3[`i']
    local dc1 : display %6.2f dc_contr1[`i']
    local dc2 : display %6.2f dc_contr2[`i']
    local dc3 : display %6.2f dc_contr3[`i']
    local dci1 : display %6.2f dc_contr_imports1[`i']
    local dci2 : display %6.2f dc_contr_imports2[`i']
    local dci3 : display %6.2f dc_contr_imports3[`i']
    
    if `yr' < 2027 {
        file write latex "`yr' & `dg1' & `dg2' & `dg3' & `dc1' & `dc2' & `dc3' & `dci1' & `dci2' & `dci3' \\" _n
    }
    else {
        file write latex "`yr' & `dg1' & `dg2' & `dg3' & `dc1' & `dc2' & `dc3' & `dci1' & `dci2' & `dci3'" _n
    }
}

* Close file
file close latex

********************************************************************************
