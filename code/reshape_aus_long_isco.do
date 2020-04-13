/*

This .do file reshapes the ANZSCO data to be long on ANZSCO x level. 

*/

* ----------------------
* Load and rename  
* ----------------------
use "${derived_data}/clean_isco_data", clear  
keep isco_code *geo_* *edu_* *ind_* *sa4_*

ds wage* isco_*, not 
foreach var in `r(varlist)' {
	rename `var' emp`var'
}

rename wage_* wage*

* ----------------------
* Rearrange to be long 
* ----------------------
reshape long emp wage, i(isco_code) j(level) string 
rename emp employment 
save "${derived_data}/long_aus_data", replace 
