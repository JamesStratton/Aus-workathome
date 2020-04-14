
* Load data 
use "${derived_data}/telework_shares", replace 

* Restrict to national data 
keep if level == "geo_aus"

* Check that mean wage calculated from collapsed ISCO-level data is similar 
	// to mean wage calculated from collapsed ANZSCO-level data; 
	// the two numbers differ because some ANZSCOs are not matched to an ISCO 
sum wage [w = employment]
assert inrange(`r(mean)', ${national_mean} * 0.95, ${national_mean} * 1.05)

* Choose as levels: < $800/week; $800-$1200 week; $1200-1600/week; $1600+ /week
gen wage_level = "" 
replace wage_level = "low" if wage <= 800 
replace wage_level = "medium-low" if wage > 800 & wage <= 1200 
replace wage_level = "medium-high" if wage > 1200 & wage <= 1600 
replace wage_level = "high" if wage > 1600

* Collapse by wage level 
collapse (mean) teleworkable [w = employment], by(wage_level)

* Create graph 
sort teleworkable 

gen pos = _n 

assert wage_level == "low" if _n == 1 
assert wage_level == "medium-low" if _n == 2 
assert wage_level == "medium-high" if _n == 3 
assert wage_level == "high" if _n == 4 

replace teleworkable = 100 * teleworkable 

tw ///
	(bar teleworkable pos, barwidth(0.5) color(dkgreen)) ///
	, /// 
	ylabel(0(20)80, nogrid) /// 
	xlabel(1 "<$800" 2 "$800-$1200" 3 "$1200-$1600" 4 ">$1600") /// 
	graphregion(color(white)) bgcolor(white) /// 
	xtitle("Mean Weekly Wage in Occupation ($)") /// 
	ytitle("Share of Jobs Able to be Completed From Home (%)") 
graph export "${results}/wages graph.pdf", as(pdf) replace 
