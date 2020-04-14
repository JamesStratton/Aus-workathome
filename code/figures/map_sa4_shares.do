* Create map shapefiles  
shp2dta using "${raw_data}/map/SA4_2016_AUST", database("${derived_data}/sa4_db") coordinates("${derived_data}/sa4_coords") genid(id) replace
use ${derived_data}/sa4_db, clear 
isid SA4_CODE16
rename SA4_CODE16 level  
replace level = "sa4_" + level 
rename SA4_NAME16 sa4_name 

* Drop SA4s that do not correspond to geographic locations
drop if strpos(level, "97") | strpos(level, "99") | strpos(level, "sa4_9")

* Merge to data at SA4 level 
merge 1:1 level using "${results}/shares_by_sa4", assert(3) nogen 

* Merge in total populations in each SA4 
merge 1:1 level using "${derived_data}/total_employed_sa4", assert(3) nogen 

* Rescale 
replace teleworkable = 100 * teleworkable 

* Check range 
assert inrange(teleworkable, 25, 65) 

* Create rural vs. urban 
gen urban = strpos(GCC_NAME16, "Greater") | strpos(GCC_NAME16, "Australian Capital Territory")
sum teleworkable if urban == 1 [w = total_employed]
sum teleworkable if urban == 0 [w = total_employed]

* Australia-wide map 
spmap teleworkable using "${derived_data}/sa4_coords" ///
	, ///
	id(id) fcolor(Blues2) clmethod(custom) clbreaks(25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65) ///
	osize(vthin ..) ocolor(white ..) /// 
	legstyle(0)
graph export "${results}/australia_map.pdf", as(pdf) replace 

* Sydney map 
gen map_sydney = 1 if strpos(sa4_name, "Sydney") > 0 | strpos(sa4_name, "Central Coast") > 0 | strpos(sa4_name, "Illawarra") > 0
assert inrange(teleworkable, 35, 65) if map_sydney == 1 
spmap teleworkable using "${derived_data}/sa4_coords" ///
	if map_sydney == 1 ///
	, ///
	id(id) fcolor(Blues2) clmethod(custom) clbreaks(35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65) ///
	osize(vthin ..) ocolor(white ..) /// 
	legenda(off)
graph export "${results}/sydney_map.pdf", as(pdf) replace 
	
* Melbourne map 
gen map_melbourne = 1 if strpos(sa4_name, "Melbourne") > 0 | strpos(sa4_name, "Geelong") > 0 | strpos(sa4_name, "Mornington Peninsula") > 0
spmap teleworkable using "${derived_data}/sa4_coords" ///
	if map_melbourne == 1 ///
	, ///
	id(id) fcolor(Blues2) clmethod(custom) clbreaks(35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65) ///
	osize(vthin ..) ocolor(white ..) ///
	legenda(off)
graph export "${results}/melbourne_map.pdf", as(pdf) replace 

* Create scale  
spmap teleworkable if map_sydney == 1 using "${derived_data}/sa4_coords" ///
	, ///
	id(id) fcolor(Blues2) clmethod(custom) clbreaks(35 40 45 50 55 60 65) ///
	osize(vthin ..) ocolor(white ..) /// 
	legstyle(2)
graph export "${results}/scale.pdf", as(pdf) replace 
