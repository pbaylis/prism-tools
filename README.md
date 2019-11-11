# prism-tools
The [PRISM](http://www.prism.oregonstate.edu/) group produces short- and long-term gridded climate datasets for the United States. These datasets are provided as `bil` (raster) files and are available for free(!) via FTP at `prism.nacse.org`.  

Because these data, in particular the monthly and daily gridded datasets, are so useful for my work and because extracting over and over from raster files can be computationally costly, I often convert them to either a tabular format (retaining the grid cell information from the rasters) or aggregate them to shapefile boundaries that are more relevant for a given project, such as state, county, or metropolitan areas. This repository holds the code to conduct both of these tasks. In the future, I may add other pieces of code that are also useful for these kinds of tasks.

## Requirements

All code on this repository is in R a variety of packages. See code for details. Note that these operations can eat up a _lot_ of memory, particularly the operations that deal with daily data.

## A note on directory structure

Because the PRISM files are large, I don't save them to github. Instead, I save them in a separate directory -- on my machine, that's `/data1/prism/raw`, and I save the processed data to `/data1/prism/processed`. You will need to adjust the scripts to suit your needs.

# Notes

## Functions of temperature variables

We often estimate the impact of temperature on some outcome. Temperature is an unusual RHS variable in the sense that its impacts are _very_ rarely linear, so most of the time we want to allow temperature to affect the outcome non-linearly. This can be implemented in a variety of ways, including bins (dummy variables for ranges of temperatures), polynomials to splines. Because the outcomes we observe usually occur at a coarser spatial scale (e.g., U.S. counties), it's better compute the non-linear transformation of temperature _before_ averaging over space, in order to retain information.

Doing this means that we construct the set of basis vectors (e.g., the set of dummy variables for our observations of temperature), then take averages over those basis vectors at the county level (for example). 

When we run our regression models using these basis vectors, the estimated coefficients represent the constants in the linear combination that represents the non-linear function (if you're lost at this point, [here](http://www.psych.mcgill.ca/misc/fda/ex-basis-a1.html) is a good reference)). We can then visually show the estimated partial effects of temperature by using the same process to construct basis vectors for the range of temperature we're interested in. This package does this for a few functions of particular interest: bins, of course, but also a quadratic in temperature. In the future I hope to make the package A) more flexible in easily accomodating other transformations and B) more usuble in terms of making those functions available for prediction after the regression. For now, these notes serve as the outline of the plan.

# Thank you

It almost goes without saying, but many thanks to the PRISM group for making these data available. They should be cited as follows, per their [terms of use](http://www.prism.oregonstate.edu/documents/PRISM_terms_of_use.pdf): 

PRISM Climate Group, Oregon State University, http://prism.oregonstate.edu, created 4 Feb 2004.
