/*

This .do file produces shares able to work from home, at various levels. 

*/

use "${derived_data}/telework_shares", replace 

* ------------------------------
* Collapse to means     
* ------------------------------
collapse (mean) teleworkable [aweight = employment], by(level)

* ------------------------------
* Produce summary tables for each cut      
* ------------------------------
gen cut = substr(level, 1, 3)

tempfile full_data 
save `full_data' 

foreach cut in geo ind sa4 edu {
	use `full_data', clear 
	keep if cut == "`cut'"
	save "${results}/shares_by_`cut'", replace 
}
