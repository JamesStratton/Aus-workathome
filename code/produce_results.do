/*

This .do file merges Australian data with teleworkable shares and produces results. 

*/


* --------------------------------------------------
* Merge together Aus data with teleworkable shares 
* --------------------------------------------------
use "${derived_data}/clean_isco_data", clear 
merge 1:1 isco_code using "${derived_data}/teleworkable_isco_level", nogen //, assert(2 3) keep(3)

* --------------------------------------------------
* Create table of state-level estimates   
* --------------------------------------------------
ds geo_* 
local geo_levels `r(varlist)'
gen geo_label = "" 
gen geo_teleworkable = . 
local i = 1 
foreach level in `geo_levels' {
	di "`level'"
	replace geo_label = "`level'" in `i'
	qui sum teleworkable [w = `level']
	replace geo_teleworkable = 100 * `r(mean)' in `i'
	local i = `i' + 1 
}

* --------------------------------------------------
* Create table of SA4-level estimates   
* --------------------------------------------------
ds sa4_* 
local sa4_levels `r(varlist)'
gen sa4_label = "" 
gen sa4_teleworkable = . 
local i = 1 
foreach level in `sa4_levels' {
	di "`level'"
	replace sa4_label = "`level'" in `i'
	qui sum teleworkable [w = `level']
	replace sa4_teleworkable = 100 * `r(mean)' in `i'
	local i = `i' + 1 
}


* --------------------------------------------------
* Create graph of industry-level estimates   
* --------------------------------------------------
ds ind_* 
local ind_levels `r(varlist)'
gen ind_label = "" 
gen ind_teleworkable = . 
local i = 1 
foreach level in `ind_levels' {
	di "`level'"
	replace ind_label = "`level'" in `i'
	qui sum teleworkable [w = `level']
	replace ind_teleworkable = 100 * `r(mean)' in `i'
	local i = `i' + 1 
}

sort ind_teleworkable 
drop if ind_label == "ind_other" 

gen pos = _n 
gen zero = 0 
gen hundred = 100 

set scheme s1color 
set scheme s2color
tw ///
	(rbar zero ind_teleworkable pos if !mi(ind_teleworkable), barwidth(0.5) color(dkgreen) horiz) /// 
	(rbar ind_teleworkable hundred pos if !mi(ind_teleworkable), barwidth(0.5) color(dkorange) horiz) /// 
	, /// 
	ylabel(18 "Education" 17 "Science & Technology" 16 "Finance" 15 "Media" 14 "Rental, Hire, Real Estate" ///
		13 "Wholesale" 12 "Arts" 11 "Public Administration" 10 "Electric., Gas, Water" 9 "Administration" /// 
		8 "Retail" 7 "Health" 6 "Manufacturing" 5 "Transportation" 4 "Mining" 3 "Agriculture" 2 "Construction" /// 
		1 "Hospitality", angle(0) nogrid) ///
	xlabel(0(20)100, nogrid) /// 
	legend(off) /// 
	ytitle("") /// 
	xtitle("Share of Jobs Able to be Completed From Home (%)") /// 
	text(18.6 25 "Can be Completed From Home", color(dkgreen) size(small)) /// 
	text(18.6 75 "Cannot be Completed From Home", color(dkorange) size(small)) /// 
	graphregion(color(white)) bgcolor(white)
graph export "${aus_work_home}/industry graph.pdf", as(pdf) replace 


* --------------------------------------------------
* Create binscatter    
* --------------------------------------------------
replace teleworkable = 100 * teleworkable
binscatter teleworkable wage_geo_aus [w = geo_aus] ///
	, /// 
	nq(20) /// 
	xtitle("2018 Mean Occupation Wage (Weekly)") /// 
	ytitle("Share in Occupation Able to Work From Home (%)") ///
	graphregion(color(white)) bgcolor(white)
graph export "${aus_work_home}/binscatter.pdf", as(pdf) replace 
