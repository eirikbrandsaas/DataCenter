********************************************************************************
* File: BEA_data.do
* Purpose: Load BEA investment data and create imputed data center investment
* Note: This file uses "fameuse", a board-internal command that relies on Fame
*       database system. This data could be found from BEA public sources.
********************************************************************************

********************************************************************************
* Load nominal and real investment data
********************************************************************************

clear

local vars igdfnqipp_xcw.q igdfnqipp.q IGDFNSFCOD_XCW.Q IGDFNSFCOD.Q

local usvars
foreach v of local vars {
	local usvars `usvars' us'`v'
}
disp "`usvars'"

fameuse `usvars' using "/fame/data/database/us.db", clear

rename igdfnqipp_q     equip
rename igdfnqipp_xcw_q equip_real
rename IGDFNSFCOD_Q    cpip
rename IGDFNSFCOD_XCW_Q cpip_real

sum cpip
assert `r(mean)' > 15 // Include assertion: Sometimes BEA change the unit (e.g., from millions to billions)
assert `r(mean)' < 100 // Include assertion: 
replace cpip      = cpip 
replace cpip_real = cpip_real 

gen year = year(date)
gen qtr  = quarter(date)
keep if year >= 2015

gen qdate = qofd(date)
replace date = qdate
format date %tq

********************************************************************************
* Calculate residual equipment investment
********************************************************************************

global yticks = "0(50)250"

reg equip date if inrange(year, $regyear_lo, $regyear_hi)
predict equip_f, xb
gen equip_r = equip - equip_f

gen inv_dc = equip_r + cpip
replace inv_dc = . if missing(cpip) | missing(equip_r)
label var inv_dc "residual of equipment + data center cpip"

save "data/inv_dc.dta", replace

file open texfile using "figures/stats.tex", write append
file write texfile "\newcommand{\trendyearlo}{$regyear_lo}" _n
file write texfile "\newcommand{\trendyearhi}{$regyear_hi}" _n
file close texfile

********************************************************************************
* Create BEA plots
********************************************************************************

use data/inv_dc.dta, clear

* Plot: High-tech equipment and structures (nominal)
twoway connected equip equip_f cpip date if year >= 2015, ///
	color($linecolor $linecolor black) ///
	lpattern(solid dash solid) ///
	msymbol(none none X) ///
	lwidth(medthick medthick medthick) ///
	ytitle("$ytitle", size(large)) ///
	xtitle("", size(large)) ///
	xlabel(#6, labsize(large)) ///
	ylabel($yticks, labsize(large)) ///
	title("", size(large)) ///
	legend(order(1 "High-tech Equipment" 2 "Trend" 3 "Structures") ///
	       rows(1) pos(6) size(large)) ///
	graphregion(color(white)) ///
	plotregion(margin(medium)) ///
	xsize(5.28) ysize(4)
graph export "figures/hightech_cpip.pdf", replace

* Plot: High-tech equipment and structures (real)
twoway connected equip_real cpip_real date if year >= 2015, ///
	color($linecolor black) ///
	lpattern(solid solid) ///
	msymbol(none X) ///
	lwidth(medthick medthick medthick) ///
	ytitle("Billions of 2017 Dollars (annual rate)", size(large)) ///
	xtitle("", size(large)) ///
	xlabel(#6, labsize(large)) ///
	ylabel($yticks, labsize(large)) ///
	title("", size(large)) ///
	legend(order(1 "High-tech Equipment" 2 "Structures") ///
	       rows(1) pos(6) size(large) span) ///
	graphregion(color(white)) ///
	plotregion(margin(medium)) ///
	xsize(5.28) ysize(4)
graph export "figures/hightech_cpip_real.pdf", replace

* Plot: Imputed data center investment
twoway line inv_dc date if year >= 2015, ///
	color(red) ///
	lpattern(dash) ///
	lwidth(medthick) ///
	ytitle("$ytitle", size(large)) ///
	xtitle("", size(large)) ///
	xlabel(#6, labsize(large)) ///
	ylabel($yticks, labsize(large)) ///
	title("", size(large)) ///
	legend(on order(1 "Imputed Data Center Investment") ///
	       rows(1) pos(6) size(large)) ///
	graphregion(color(white)) ///
	plotregion(margin(medium)) ///
	xsize(5.28) ysize(4)
graph export "figures/imputed_datacenter.pdf", replace

********************************************************************************
* Export data for 508 compliance
********************************************************************************

* Figure 1 (both panels)
export delimited equip equip_f cpip inv_dc date ///
    using figures/508_fig1.csv if year >= 2015, replace

* Figure S.1
export delimited equip_real cpip_real date ///
    using figures/508_figS1.csv if year >= 2015, replace

********************************************************************************
