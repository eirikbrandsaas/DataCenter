echo; echo Running R Code
Rscript Main.R
echo; echo Done running R code

echo; echo Running Stata Code
stata-mp -b runall.do
echo; echo Done running Stata code

echo; echo Running R Code for animation
Rscript create_vintage_gifs.R
echo; echo Done running R code