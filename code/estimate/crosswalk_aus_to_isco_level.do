* ------------------------------
* Crosswalk Australian data to ISCO codes       
* ------------------------------

* ------------------------------
* Import ISCO codes       
* ------------------------------
import excel "${raw_data}/1220.0 ANZSCO Correspondence to ISCO-08 v2.xls", sheet("ANZSCO Version 1.2 to ISCO-08") cellrange(A9:E1286) clear
rename A anzsco_code 
rename B anzsco_text 
rename C isco_code 
drop D 
rename E isco_text 
drop if mi(isco_code) 

/*
* Drop military 
drop if inlist(isco_code, "0110", "0210", "0310")
*/
isid anzsco_code isco_code
keep anzsco_code isco_code isco_text  
tempfile isco_codes 
save `isco_codes' 

* ------------------------------
* Load Australian data        
* ------------------------------
* Load 
use "${derived_data}/clean_anzsco_data", clear 

tempfile anzsco_data 
save `anzsco_data' 

* ------------------------------
* Loop over levels         
* ------------------------------
ds geo_* ind_* sa4_* edu_* 
local levels `r(varlist)' 

foreach level in `levels' {
	sum `level'
	if `r(N)' == 0 drop `level'
}

ds geo_* ind_* sa4_* edu_* 
local levels `r(varlist)' 

foreach level in `levels' {

	di "`level'"
	
	qui {

	use `anzsco_data', clear 
	keep anzsco_code anzsco_text `level' weekly_wage 
	rename `level' employment 
		
	* ------------------------------
	* Merge ISCO codes to Australian data       
	* ------------------------------
	merge 1:m anzsco_code using `isco_codes'

	* Distribute employment over codes where matched multiple ISCO codes to an ANZSCO code 
	egen isco_per_anzsco = count(isco_code), by(anzsco_code) 
	replace employment = employment/isco_per_anzsco if isco_per_anzsco > 0 & !mi(isco_per_anzsco)

	* Distribute labourers NEC over rest in category 
	gen labourer = strpos(anzsco_text, "Labourer") > 0 
	egen total_labourer = sum(employment) if labourer == 1 & !mi(isco_code) 
	gen share_labourer = employment/total_labourer 
	gen to_distribute_labourer = employment if anzsco_text == "Labourers nec"
	egen total_to_distribute_labourer = max(to_distribute_labourer), by(labourer)
	gen test = share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
	replace employment = employment + share_labourer * total_to_distribute_labourer if !mi(total_to_distribute_labourer)
	drop if anzsco_text == "Labourers nec"

	* Distribute sign erector and road traffic controller into labourers 
	sum _merge if anzsco_text == "Sign Erector" | anzsco_text == "Road Traffic Controller"
	if `r(N)' > 0 {
	assert `r(mean)' == 1 
	sum employment if anzsco_text == "Sign Erector"
	if `r(N)' > 0 {
	replace employment = employment + `r(mean)' if anzsco_text == "Builder's Labourer"
	}
	sum employment if anzsco_text == "Road Traffic Controller"
	if `r(N)' > 0 {
	replace employment = employment + `r(mean)' if anzsco_text == "Builder's Labourer"
	}
	}
	drop if anzsco_text == "Road Traffic Controller"
	drop if anzsco_text == "Sign Erector"
	
	* Distribute ticket collector into ticket seller  
	sum _merge if anzsco_text == "Ticket Collector or Usher"
	if `r(N)' > 0 {
	assert `r(mean)' == 1 
	sum employment if anzsco_text == "Ticket Collector or Usher"
	if `r(N)' > 0 {
	replace employment = employment + `r(mean)' if anzsco_text == "Ticket Seller" 
	}
	}
	drop if anzsco_text == "Ticket Collector or Usher"

	* Distribute trolley collector into car park attendant 
	sum _merge if anzsco_text == "Trolley Collector"
	if `r(N)' > 0 {
	assert `r(mean)' == 1 
	sum employment if anzsco_text == "Trolley Collector"
	if `r(N)' > 0 {
	replace employment = employment + `r(mean)' if anzsco_text == "Car Park Attendant" 
	}
	}
	drop if anzsco_text == "Trolley Collector"

	* Assert that no longer missing 
	assert !mi(isco_code) 
 
	* Note that a small number of ISCO codes are still unmatched, but there are equivalents elsewhere
	/*
	assert _merge == 2 if inlist(isco_code, "2342", "2341", "2230", "3253", "2341", "5312", "2341")
	assert inlist(isco_code, "2342", "2341", "2230", "3253", "2341", "5312", "2341") if _merge == 2 
	drop if inlist(isco_code, "2342", "2341", "2230", "3253", "2341", "5312", "2341")
	
	assert _merge == 2 if inlist(anzsco_code, "241112", "241211", "241212", "241311", "252215") 
		"411512", "422113", "422113", "422114", "422114")
	*/
	drop if _merge == 2 
	
	* ------------------------------
	* Collapse to level of ISCO code      
	* ------------------------------
	tempfile pre_collapse 
	save `pre_collapse' 
	
	* Collapse to sums 
	collapse (sum) employment, by(isco_code) 
	tempfile sums 
	save `sums' 
	
	* Collapse to mean wages 
	use `pre_collapse', clear
	gen all = 1 
	collapse (mean) weekly_wage [w = employment], by(isco_code)
	
	* Merge collapse data together 
	merge 1:1 isco_code using `sums'   
 
	* Rename  
	rename employment `level' 
	rename weekly_wage wage_`level' 

	* Save
	tempfile `level'_data 
	save ``level'_data' 
	}
}

* Merge together data for each level   
use `geo_aus_data'
foreach level in `levels' {
	merge 1:1 isco_code using ``level'_data', assert(3) nogen 
}

* ------------------------------
* Output data        
* ------------------------------
save "${derived_data}/clean_isco_data", replace 
