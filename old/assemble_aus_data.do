* ------------------------------
* Assemble Australian data       
* ------------------------------
* Import data 
import excel "${data}/1. Census 2016 Occupation Summary - Australia.xlsx", sheet("Total-State") clear cellrange(A9:V1871) firstrow

* Rename variables 
rename NewSouthWales nsw  
rename Victoria vic 
rename Queensland qld 
rename SouthAustralia sa 
rename WesternAustralia wa 
rename Tasmania tas 
rename NorthernTerritory nt 
rename AustralianCapitalTerritory act 
rename Australia aus 

tempfile import 
save `import' 

* Loop over states, territories, and country 
foreach geo in aus {

	* Load data 
	use `import', clear 

	* Rename geography to employment 
	rename `geo' employment
	
	* Check that sum of categories matches total employment 
	sum employment if length(ANZSCO) == 6 
	local listed_values = `r(sum)' 
	sum employment if UIDANZSCO == "&&&&&& Not stated"
	assert `r(N)' == 1 
	local unlisted_values = `r(mean)'
	local total = `listed_values' + `unlisted_values'
	di `total'
	sum employment if UIDANZSCO == "0 Total Employed"
	assert `r(N)' == 1 
	assert inrange(`total', 0.99 * `r(mean)', 1.01 * `r(mean)')

	* Keep relevant data 
	keep if length(ANZSCO) == 6 
	drop if Occupation == "Not stated"
	drop if Occupation == "Inadequately described" 

	rename ANZSCO anzsco_code 
	rename Occupation anzsco_text 
	keep anzsco_code anzsco_text employment

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

	sum employment 
	local employment = `r(sum)'

	forvalues i = 1/4 {
		gen to_distribute_`i' = employment if code_is_`i'_dig == 1
		egen total_to_distribute_`i' = sum(to_distribute_`i'), by(code_`i'_dig)
		egen total_`i' = sum(employment) if code_is_`i'_dig == 0, by(code_`i'_dig) 
		gen share_`i' = employment/total_`i' 
		replace employment = employment + share_`i' * total_to_distribute_`i' if !mi(total_to_distribute_`i')
		drop if code_is_`i'_dig == 1 
		sum employment 
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
	replace employment = employment/isco_per_anzsco if isco_per_anzsco > 0 & !mi(isco_per_anzsco)

	* Drop military 
	drop if inlist(isco_code, "0110", "0210", "0310")

	* Distribute labourers NEC over rest in category 
	gen labourer = strpos(anzsco_text, "Labourer") > 0 
	egen total_labourer = sum(employment) if labourer == 1 & !mi(isco_code) 
	gen share_labourer = employment/total_labourer 
	gen to_distribute_labourer = employment if anzsco_text == "Labourers nec"
	egen total_to_distribute_labourer = max(to_distribute_labourer), by(labourer)
	gen test = share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
	replace employment = employment + share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
	drop if anzsco_text == "Labourers nec"

	* Distribute sign erector and road traffic into labourers 
	sum _merge if anzsco_text == "Sign Erector" | anzsco_text == "Road Traffic Controller"
	assert `r(mean)' == 2 
	sum employment if anzsco_text == "Sign Erector"
	replace employment = employment + `r(mean)' if anzsco_text == "Builder's Labourer"
	drop if anzsco_text == "Sign Erector"
	sum employment if anzsco_text == "Road Traffic Controller"
	replace employment = employment + `r(mean)' if anzsco_text == "Builder's Labourer"
	drop if anzsco_text == "Road Traffic Controller"

	* Distribute ticket collector into ticket seller  
	sum _merge if anzsco_text == "Ticket Collector or Usher"
	assert `r(mean)' == 2 
	sum employment if anzsco_text == "Ticket Collector or Usher"
	replace employment = employment + `r(mean)' if anzsco_text == "Ticket Seller" 
	drop if anzsco_text == "Ticket Collector or Usher"

	* Distribute trolley collector into car park attendant 
	sum _merge if anzsco_text == "Trolley Collector"
	assert `r(mean)' == 2 
	sum employment if anzsco_text == "Trolley Collector"
	replace employment = employment + `r(mean)' if anzsco_text == "Car Park Attendant" 
	drop if anzsco_text == "Trolley Collector"

	* Assert that no longer missing 
	assert !mi(isco_code) 
	
	* ------------------------------
	* Collapse to level of ISCO code      
	* ------------------------------
	* Collapse 
	collapse (sum) employment, by(isco_code) 
	
	* Rename  
	rename employment `geo'_employment 

	* Save
	tempfile `geo'_data 
	save ``geo'_data' 
}

* Merge together data for each geography  
use `aus_data'
foreach geo in nsw vic qld sa wa tas nt act {
	merge 1:1 isco_code using ``geo'_data', assert(3) nogen 
}

save "${data}aus_data_isco_state", replace 
