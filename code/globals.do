********************************************************************************
* File: globals.do
* Purpose: Set global parameters and directories
********************************************************************************

clear all
set more off
set varabbrev off

* Random seed
global seed = 170330815  // ZIP code for Hershey's

* Model assumptions
global maxtimeplan = 48  // Months a project can be in planning before being labelled as cancelled
global sims = 1000       // Number of simulations

* Install required packages
cap ssc install egenmore     // Needed for nvals in egen
cap ssc install blindschemes
cap ssc install estout

* Install fame commands
cap net install fametools, from(/mcr/local/lm-stata-pkg)

* Plot settings
set scheme plotplain

* Trend line years
global regyear_lo = 2015
global regyear_hi = 2022

* Import share of datacenters
* Assumes that investment is: 30% domestic structures and 70% high-tech imports,
* of which only 20% are domestic (0.3 + 0.7*0.2 = 0.44). See text for more.
global importshare_datacenter = 0.44

* Define common graph settings
global color1    "navy%15"
global color2    "navy%25"
global color3    "navy%40"
global color4    "navy%55"
global linecolor "navy"
global ytitle    "Billons of Dollars (annual rate)"

* Export global settings to LaTeX file
file open texfile using "figures/stats.tex", write replace
file write texfile "\newcommand{\Nsims}{$sims}" _n
file write texfile "\newcommand{\maxtimeplan}{$maxtimeplan}" _n
file close texfile

********************************************************************************
