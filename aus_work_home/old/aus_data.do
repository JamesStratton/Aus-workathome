* ------------------------------
* Import data on Australian workers      
* ------------------------------
import excel "${data}/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("Total-State") clear cellrange(A9:V1871) firstrow

* Check that sum of categories matches total employment 
sum Australia if length(ANZSCO) == 6 
local aus_listed_values = `r(sum)' 
sum Australia if UIDANZSCO == "&&&&&& Not stated"
assert `r(N)' == 1 
local aus_unlisted_values = `r(mean)'
local aus_total = `aus_listed_values' + `aus_unlisted_values'
di `aus_total'
sum Australia if UIDANZSCO == "0 Total Employed"
assert `r(N)' == 1 
assert inrange(`aus_total', 0.99 * `r(mean)', 1.01 * `r(mean)')

* Keep relevant data 
keep if length(ANZSCO) == 6 
drop if Occupation == "Not stated"
drop if Occupation == "Inadequately described" 

rename ANZSCO anzsco_code 
rename Occupation anzsco_text 
rename Australia aus_employment 
keep anzsco_code anzsco_text aus_employment

* Check structure 
isid anzsco_code 

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

sum aus_employment 
local employment = `r(sum)'

forvalues i = 1/4 {
	gen to_distribute_`i' = aus_employment if code_is_`i'_dig == 1
	egen total_to_distribute_`i' = sum(to_distribute_`i'), by(code_`i'_dig)
	egen total_`i' = sum(aus_employment) if code_is_`i'_dig == 0, by(code_`i'_dig) 
	gen share_`i' = aus_employment/total_`i' 
	replace aus_employment = aus_employment + share_`i' * total_to_distribute_`i' if !mi(total_to_distribute_`i')
	drop if code_is_`i'_dig == 1 
	di `employment' 
	sum aus_employment 
	di `r(sum)'
	assert inrange(`r(sum)', `employment' * 0.99, `employment' * 1.01)
}

* Save as tempfile 
tempfile aus_worker_data 
save `aus_worker_data' 

* ------------------------------
* Import ISCO codes       
* ------------------------------
import excel "${data}/1220.0 ANZSCO Correspondence to ISCO-08 v2.xls", sheet("ANZSCO Version 1.2 to ISCO-08") cellrange(A9:E1286) clear
rename A anzsco_code 
rename B anzsco_text 
rename C isco_code 
drop D 
rename E isco_text 
drop if mi(isco_code) 
isid anzsco_code isco_code
keep anzsco_code isco_code isco_text 

* ------------------------------
* Merge ISCO codes to Australian data       
* ------------------------------
merge m:1 anzsco_code using `aus_worker_data'

* Distribute employment over codes where matched multiple ISCO codes to an ANZSCO code 
egen isco_per_anzsco = count(isco_code), by(anzsco_code) 
replace aus_employment = aus_employment/isco_per_anzsco if isco_per_anzsco > 0 & !mi(isco_per_anzsco)

* Drop military 
drop if inlist(isco_code, "0110", "0210", "0310")

* Distribute labourers NEC over rest in category 
gen labourer = strpos(anzsco_text, "Labourer") > 0 
egen total_labourer = sum(aus_employment) if labourer == 1 & !mi(isco_code) 
gen share_labourer = aus_employment/total_labourer 
gen to_distribute_labourer = aus_employment if anzsco_text == "Labourers nec"
egen total_to_distribute_labourer = max(to_distribute_labourer), by(labourer)
gen test = share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
replace aus_employment = aus_employment + share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
drop if anzsco_text == "Labourers nec"

* Distribute sign erector and road traffic into labourers 
sum _merge if anzsco_text == "Sign Erector" | anzsco_text == "Road Traffic Controller"
assert `r(mean)' == 2 
sum aus_employment if anzsco_text == "Sign Erector"
replace aus_employment = aus_employment + `r(mean)' if anzsco_text == "Builder's Labourer"
drop if anzsco_text == "Sign Erector"
sum aus_employment if anzsco_text == "Road Traffic Controller"
replace aus_employment = aus_employment + `r(mean)' if anzsco_text == "Builder's Labourer"
drop if anzsco_text == "Road Traffic Controller"

* Distribute ticket collector into ticket seller  
sum _merge if anzsco_text == "Ticket Collector or Usher"
assert `r(mean)' == 2 
sum aus_employment if anzsco_text == "Ticket Collector or Usher"
replace aus_employment = aus_employment + `r(mean)' if anzsco_text == "Ticket Seller" 
drop if anzsco_text == "Ticket Collector or Usher"

* Distribute trolley collector into car park attendant 
sum _merge if anzsco_text == "Trolley Collector"
assert `r(mean)' == 2 
sum aus_employment if anzsco_text == "Trolley Collector"
replace aus_employment = aus_employment + `r(mean)' if anzsco_text == "Car Park Attendant" 
drop if anzsco_text == "Trolley Collector"

* Assert that no longer missing 
assert !mi(isco_code) 

* ------------------------------
* Collapse to level of ISCO code      
* ------------------------------
collapse (sum) aus_employment, by(isco_code) 
save "${data}aus_employment_isco_level", replace 
