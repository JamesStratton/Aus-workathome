/*

This .do file cleans ANZSCO data and adds in wages at the four-digit level. 

*/

* ------------------------------
* Load full ANZSCO data             
* ------------------------------
* Load 
use "${derived_data}/full_anzsco_data", replace  

* Keep relevant data 
keep if length(anzsco_code) == 6 
drop if anzsco_text == "Not stated"
drop if anzsco_text == "Inadequately described" 

* Six-digit ANZSCO codes should not end in zero; only NFD 
assert substr(anzsco_code, 5, 2) == "00" if  substr(anzsco_text, -3, 3) == "nfd" 
assert substr(anzsco_text, -3, 3) == "nfd" if substr(anzsco_code, 5, 2) == "00" 

* Distribute NFD over rest in category 
forvalues i = 1/4 {
	local remaining_digits = 6 - `i'
	local zeros = substr("00000", 1, `remaining_digits')
	local start_pos = `i' + 1 
	gen code_is_`i'_dig = (substr(anzsco_code, `start_pos', `remaining_digits') == "`zeros'") 
}

forvalues i = 1/4 {
	gen code_`i'_dig = substr(anzsco_code, 1, `i') 
}

ds geo_* ind_* sa4_* edu_* 
local levels `r(varlist)'

forvalues i = 1/4 {
	foreach level in `levels' {
		gen to_distribute_`i' = `level' if code_is_`i'_dig == 1
		egen total_to_distribute_`i' = sum(to_distribute_`i'), by(code_`i'_dig)
		egen total_`i' = sum(`level') if code_is_`i'_dig == 0, by(code_`i'_dig) 
		gen share_`i' = `level'/total_`i' 
		replace `level' = `level' + share_`i' * total_to_distribute_`i' if !mi(total_to_distribute_`i')
		drop if code_is_`i'_dig == 1 
		/*
		di `employment' 
		sum `level' 
		di `r(sum)'
		assert inrange(`r(sum)', `employment' * 0.99, `employment' * 1.01)
		*/
		drop to_distribute_`i'
		drop total_to_distribute_`i'
		drop share_`i'
		drop total_`i'
	}
	drop code_is_`i'_dig
	drop code_`i'_dig 
} 

* Create four-digit codes for merge 
gen four_digit_code = substr(anzsco_code, 1, 4)

* Save tempfile 
tempfile anzsco_data 
save `anzsco_data' 

* ------------------------------
* Merge in data on wages              
* ------------------------------
* Import data 
import excel "${raw_data}/abs_wage_data.xls", sheet("Table_1") cellrange(A7:D361) clear

* Rename variables and keep relevant data 
rename A anzsco_code_text 
rename D weekly_wage 
keep anzsco_code_text weekly_wage
drop if anzsco_code_text == "All occupations"
gen four_digit_code = substr(anzsco_code_text, 1, 4)
keep four_digit_code weekly_wage
isid four_digit_code 

* Merge onto main file 
merge 1:m four_digit_code using `anzsco_data', assert(2 3) 
assert inlist(anzsco_text, "Aquaculture Worker", "Senior Non-commissioned Defence Force Member", ///
	"Aquaculture Farmer", "Defence Force Member - Other Ranks") if _merge == 2 
drop _merge 

* ------------------------------
* Save              
* ------------------------------
* Save output 
save "${derived_data}/clean_anzsco_data", replace 
