/*

This .do file is a master file for the full code. 

*/

* --------------------------------------------------
* Set relevant globals 
* --------------------------------------------------
global aus_work_home "/Users/Jimmy/Desktop/GitHub/Aus-workathome"
global raw_data  "${aus_work_home}/raw_data"
global derived_data "${aus_work_home}/derived_data"
global results "${aus_work_home}/results"
global code "${aus_work_home}/code"

* --------------------------------------------------
* Set graphing options  
* --------------------------------------------------
set scheme s2color 
global img pdf 

* --------------------------------------------------
* Run code  
* --------------------------------------------------
*** Create results

* Create Australian employment data at ANZSCO code level 
do "${code}/create_aus_anzsco_level.do"

* Clean Australian employment data at ANZSCO code level
do "${code}/clean_aus_anzsco_level.do"

* Crosswalk Australian employment data to ISCO code level 
do "${code}/crosswalk_aus_to_isco_level.do"

* Reshape Australian employment data to be long on ISCO x level 
do "${code}/reshape_aus_long_isco.do"

* Crosswalk teleworkable shares at ISCO code level 
do "${code}/crosswalk_oes_to_ISCO_level.do"

* Create summary tables 
do "${code}/summary_tables_by_cut.do"

*** Create figures

* Graph industry shares 
do "${code}/industry_shares.do"

* Graph education shares 
do "${code}/education_shares.do"

* Map of Australian shares 
do "${code}/maps.do"
