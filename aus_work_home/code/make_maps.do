* Make map 
shp2dta using ${raw_data}/map/SA4_2016_AUST, database(${derived_data}/sa4_db) coordinates(${derived_data}/sa4_coords) genid(id) replace
use ${derived_data}/sa4_db, clear 
isid SA4_CODE16
rename SA4_CODE16 sa4_code  
rename SA4_NAME16 sa4_name

merge 1:1 sa4_code using "${derived_data}/sa4_teleworkable"
drop if strpos(sa4_name, "Migratory - Offshore - Shipping") > 0 
drop if strpos(sa4_name, "No usual address") > 0 

* Australia-wide map 
spmap sa4_teleworkable using ${derived_data}/sa4_coords, id(id) fcolor(Blues) clmethod(custom) clbreaks(20 30 40 50 60)
graph export 

* Sydney map 
spmap sa4_teleworkable using ${derived_data}/sa4_coords ///
	if strpos(sa4_name, "Sydney") > 0 | strpos(sa4_name, "Central Coast") > 0 | strpos(sa4_name, "Illawarra") > 0 ///
	, id(id) fcolor(Blues) clmethod(custom) clbreaks(20 30 40 50 60 70) ///
	osize(vthin ..) ocolor(white ..)
	
* Melbourne map 
spmap sa4_teleworkable using ${derived_data}/sa4_coords ///
	if strpos(sa4_name, "Melbourne") > 0 | strpos(sa4_name, "Geelong") > 0 | strpos(sa4_name, "Mornington Peninsula") > 0 ///
	, id(id) fcolor(Blues) clmethod(custom) clbreaks(20 30 40 50 60 70) ///
	osize(vthin ..) ocolor(white ..)
