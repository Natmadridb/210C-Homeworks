/* Homework 2 Macroeconomics 210c
Natalia Madrid (nmadrid@udec.cl)*/


clear all
cd "/Users/nataliamadrid/Desktop/UCSD/Spring_Quarter/Macroeconomics_210C/Johaness_210C/Homeworks/Mydirectory/HW2"

*********************** QUESTION 1******************************
/* Settings for graph and data*/

* Packages 
//ssc install blindschemes, replace
//ssc install GRSTYLE, replace
//ssc install freduse, replace
//ssc install palettes
//ssc install colrspace
	
*Establish color scheme
global bgcolor "255 255 255"
	global fgcolor "15 60 15"
		/* Decomp Colors */
	global color1 "255 140 0"      // Dark orange
	global color2 "100 149 237"    // Cornflower blue
	global color3 "154 205 50"     // Yellow-green
		
		
* Establish some graphing setting
	graph drop _all
	set scheme plotplainblind 
	grstyle init
	grstyle set legend 6, nobox
	
	grstyle color background "${bgcolor}"
	grstyle color major_grid "${fgcolor}"
	grstyle set color "${fgcolor}": axisline major_grid 
	grstyle linewidth major_grid thin
	grstyle yesno draw_major_hgrid yes
	grstyle yesno grid_draw_min yes
	grstyle yesno grid_draw_max yes
	grstyle anglestyle vertical_tick horizontal
	
* Load data from FRED 

/* 1. Get data from FRED  */ 
		
		local tsvar "FEDFUNDS UNRATE GDPDEF USRECM"
		
			foreach v of local tsvar {
				import delimited using "data/`v'.csv", clear case(preserve)
				rename DATE date
				tempfile `v'_dta
				save ``v'_dta', replace
			}
			use `FEDFUNDS_dta', clear
			keep date
			foreach v of local tsvar {
				joinby date using ``v'_dta', unm(b)
				drop _merge
			}
		
	
	/* 2. Clean data */
			gen daten = date(date, "YMD")
			format daten %td
		drop if yofd(daten) < 1960  | yofd(daten) > 2023  
		gen INFL = 100*(GDPDEF - GDPDEF[_n-12])/GDPDEF[_n-12] 
			la var INFL "Inflation Rate"
			la var FEDFUNDS "Federal Funds Rate"
			la var UNRATE "Unemployment Rate"
			la var daten Date  
		local tsvar "FEDFUNDS UNRATE INFL" 

/* Part a) Plot the data.*/
		
	/* 1. Format recession bars */{
		egen temp1 = rowmax(`tsvar')
		sum temp1
		local max = ceil(r(max)/5)*5
		generate recession = `max' if USREC == 1
		drop temp1
		egen temp1 = rowmin(`tsvar')
		sum temp1
		if r(min) < 0 {
			local min = ceil(abs(r(min))/5)*-5
		}
		if r(min) >= 0 {
			local min = floor(abs(r(min))/5)*5
		}
			replace  recession = `min' if USREC == 0 
		drop temp1
		la var recession "NBER Recessions"
	}
	/* 2. Plot the data*/
	
{
	tsset daten
	twoway (area recession daten, color(gs14) base(`min')) ///
		(tsline FEDFUNDS, lc("${color1}") lp(solid))  || ///
		(tsline UNRATE, lc("${color2}") lp(solid) ) || ///
		(tsline INFL, lc("${color3}") lp(solid) ) || ///
		, ///
		title("Monthly U.S. Macroeconomic Indicators, 1960-2023", c("${fgcolor}")) ///
		tlabel(, format(%dCY) labc("${fgcolor}")) ttitle("") ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		caption("Source: FRED." "Note: Shaded regions denote recessions.", c("${fgcolor}")) ///
		ytitle("Percent", c("${fgcolor}")) ///
		name(raw_data___) ///
		legend(on order(2 3 4) pos(6) bmargin(tiny) r(1))  //bplacement(ne) 
		graph export "figures/fig1.pdf", replace
	}	

/* Part b) Aggregate all series to a quarterly frequency by averaging over months */

{
	gen dateq = qofd(daten)
	collapse (mean) `tsvar' (max) recession (last) date daten, by(dateq)
	tsset dateq, quarterly
	keep if (yofd(daten) >= 1960) & (yofd(daten) <= 2007)
	var INFL UNRATE FEDFUNDS, lags(1/4)
		irf set var_results, replace
		irf create var_result, step(20) set(var_results) replace
		irf graph irf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) byopts(yrescale) /// INFL UNRATE 
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(var_results)
			graph export "figures/fig2.pdf", replace
}	


/* Part d) Plot the IRFs from the SVAR with the same ordering */
{
	/* Manual Choleshy Decomp */
	matrix A = (1,0,0 \ .,1,0 \ .,.,1)
	matrix B = (.,0,0 \ 0,.,0 \ 0,0,.)
	svar INFL UNRATE FEDFUNDS, lags(1/4) aeq(A) beq(B)
	irf create mysirf, set(mysirfs) step(20) replace
	irf graph sirf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) ///
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(svar_results_manual)

	var INFL UNRATE FEDFUNDS, lags(1/4)
	irf create myirf, set(myirfs) step(20) replace
	irf graph oirf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) ///
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(svar_results_oirf)
			graph export "figures/fig3.pdf", replace
	
}

/* Part f) Plot the time series of your identified monetary shocks */
{
matrix A = (1,0,0 \ .,1,0 \ .,.,1)
matrix B = (.,0,0 \ 0,.,0 \ 0,0,.)
svar INFL UNRATE FEDFUNDS, lags(1/4) aeq(A) beq(B)
predict resid_INFL , residuals equation(INFL)
predict resid_UNRATE , residuals equation(UNRATE)
predict resid_FEDFUNDS , residuals equation(FEDFUNDS)

drop if resid_FEDFUNDS==.

gen rec=0
replace rec=6 if recession>1
gen min=-4
replace rec=-4 if recession==0
la var rec "NBER Recessions"

twoway (area rec dateq, color(gs14) base(-4)) ///
(tsline resid_FEDFUNDS, lc("${color2}") lp(solid)), title("Identified Monetary Shocks", c("${fgcolor}")) ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		ytitle("Shock", c("${fgcolor}")) 	
	graph export "figures/fig4.pdf", replace
}


*********************** QUESTION 2******************************
clear all

*Establish color scheme
global bgcolor "255 255 255"
	global fgcolor "15 60 15"
		/* Decomp Colors */
	global color1 "255 140 0"      // Dark orange
	global color2 "100 149 237"    // Cornflower blue
	global color3 "154 205 50"     // Yellow-green
		
		
* Establish some graphing setting
	graph drop _all
	set scheme plotplainblind 
	grstyle init
	grstyle set legend 6, nobox
	
	grstyle color background "${bgcolor}"
	grstyle color major_grid "${fgcolor}"
	grstyle set color "${fgcolor}": axisline major_grid 
	grstyle linewidth major_grid thin
	grstyle yesno draw_major_hgrid yes
	grstyle yesno grid_draw_min yes
	grstyle yesno grid_draw_max yes
	grstyle anglestyle vertical_tick horizontal
	
* IMPORT AND CLEAN DATA
	local tsvar "FEDFUNDS UNRATE GDPDEF USRECM"

		foreach v of local tsvar {
				import delimited using "data/`v'.csv", clear case(preserve)
				rename DATE date
				tempfile `v'_dta
				save ``v'_dta', replace
			}
			use `FEDFUNDS_dta', clear
			keep date
			foreach v of local tsvar {
				joinby date using ``v'_dta', unm(b)
				drop _merge
			}
			
			
			gen daten = date(date, "YMD")
			format daten %td
		
		drop if yofd(daten) < 1960  | yofd(daten) > 2023 // data is per quarter in 1947 but per month after 
		gen INFL = 100*(GDPDEF - GDPDEF[_n-12])/GDPDEF[_n-12] //year to year inflation
			la var INFL "Inflation Rate"
			la var FEDFUNDS "Federal Funds Rate"
			la var UNRATE "Unemployment Rate"
			la var daten Date // re=label date 
		local tsvar "FEDFUNDS UNRATE INFL" // Reset local varlist to include created inflation var
	
* Format recession bars
		
		egen temp1 = rowmax(FEDFUNDS UNRATE USRECM) // Drop GDP deflator out, skipped it from graph since its not a rate
		sum temp1
		local max = ceil(r(max)/5)*5 
		generate recession = `max' if USREC == 1
		drop temp1
		egen temp1 = rowmin(FEDFUNDS UNRATE GDPDEF USRECM)
		sum temp1
		if r(min) < 0 {
			local min = ceil(abs(r(min))/5)*-5
		}
		if r(min) >= 0 {
			local min = floor(abs(r(min))/5)*5
		} //r(min) aqui es 0
			replace  recession = `min' if USREC == 0 //
		drop temp1
		la var recession "NBER Recessions"
	
	{
	gen dateq = qofd(daten) // quarters since 1960q1

collapse (mean) FEDFUNDS UNRATE INFL (max) recession (last) date daten, by(dateq)
}

/* Part a) Merge the dataset.*/
rename date rdate
rename dateq date
merge 1:1 date using "/Users/nataliamadrid/Desktop/UCSD/Spring_Quarter/Macroeconomics_210C/Johaness_210C/Homeworks/Mydirectory/HW2/data/Monetary_shocks/RR_monetary_shock_quarterly.dta" ,keepusing(resid_romer)

replace resid_romer=0 if _merge==1



/* Part b) Construct IFR from the estimation equation.*/

tsset date, quarterly
var INFL UNRATE FEDFUNDS, lags(1/8) exog(L(0/12).resid_romer)
irf set var_controls, replace
		irf create var_controls, step(20) set(var_controls) replace
		irf graph irf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) byopts(yrescale) /// 
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(var_controls)
			graph export "figures/fig5.pdf", replace
		
		irf graph dm, impulse(resid_romer) irf(var_controls)
			graph export "figures/fig5_1.pdf", replace
			
/* Part c) Estimate SVAR .*/

predict resid_FEDFUNDS , residuals equation(FEDFUNDS)

drop if resid_FEDFUNDS==.

matrix A = (1,0,0,0 \ .,1,0,0 \ .,.,1,0 \ .,.,.,1)
matrix B = (.,0,0,0 \ 0,.,0,0 \ 0,0,.,0 \ 0,0,0,.)
svar resid_romer INFL UNRATE FEDFUNDS, lags(1/4) aeq(A) beq(B)
	irf create mysirf, set(mysirfs) step(20) replace
	irf graph sirf, impulse(resid_romer) response(resid_romer INFL UNRATE FEDFUNDS) ///
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(svar_results)
			graph export "figures/fig6.pdf", replace
			graph export "figures/fig6_onlyRR.pdf", replace // made one only with impulse RR

* Plot fedresid vs romer resid_FEDFUNDS
			twoway (area rec date, color(gs14) base(`min')) ///
(tsline resid_FEDFUNDS, lc("${color2}") lp(solid)) ///
(tsline resid_romer, lc("${color1}") lp(solid)), title("Comparison between Identified Residuals (Monetary Shocks) and R&R Shocks", c("${fgcolor}")) ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		ytitle("Shock", c("${fgcolor}")) 	
	graph export "figures/fig7.pdf", replace
			
			* Plot fedresid vs romer resid_FEDFUNDS including FEDFUNDS
			twoway (tsline resid_FEDFUNDS, lc("${color2}") lp(solid)) ///
(tsline resid_romer, lc("${color1}") lp(solid)) /// 
(tsline FEDFUNDS, lc("${color3}") lp(dash)), title("Comparison between Identified Residuals (Monetary Shocks) and R&R Shocks", c("${fgcolor}")) ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		ytitle("Shock", c("${fgcolor}")) 	
	graph export "figures/fig8.pdf", replace
