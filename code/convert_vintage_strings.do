* Calculate vintage cutoffs
global vintage_cutoff = tm(${y}m${m})
global vintage_str = string($vintage_cutoff, "%tm")

* Calculate forecast quarter based on vintage month
* Logic: With data through month X, forecast through specific quarter
*   m1, m2       -> Q3 of same year (have Q1 data, forecast through Q2,Q3)
*   m3, m4, m5   -> Q4 of same year (have Q1+, forecast through Q3,Q4)
*   m6, m7, m8   -> Q1 of next year (have Q1-Q2, forecast through Q3,Q4,Q1)
*   m9, m10, m11 -> Q2 of next year (have Q1-Q3, forecast through Q4,Q1,Q2)
*   m12          -> Q3 of next year (have full year, forecast through Q1,Q2,Q3)
local vintage_month = mod($m, 12)
if `vintage_month' == 0 local vintage_month = 12
local vintage_month = $m
local vintage_year = year(dofm($vintage_cutoff))

if inlist(`vintage_month', 1, 2) {
	global forecast_qtr = tq(`vintage_year'q3)
}
else if inlist(`vintage_month', 3, 4, 5) {
	global forecast_qtr = tq(`vintage_year'q4)
}
else if inlist(`vintage_month', 6, 7, 8) {
	global forecast_qtr = tq(`=`vintage_year'+1'q1)
}
else if inlist(`vintage_month', 9, 10, 11) {
	global forecast_qtr = tq(`=`vintage_year'+1'q2)
}
else if `vintage_month' == 12 {
	global forecast_qtr = tq(`=`vintage_year'+1'q3)
}

global M = string(`_m',"%02.0f") // Converts 1 -> 1, but leaves 10->10, i.e., add leading 0 to first 9 months
global Y = string(`_y',"%02.0f") 
display "month $m vintage_month = `vintage_month'. String month = $M. String year = $Y"
display "Vintage: $vintage_str (month `vintage_month' of `vintage_year')"
display "Forecast through: " %tq $forecast_qtr
