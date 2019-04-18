# prism-tools
The [PRISM](http://www.prism.oregonstate.edu/) group produces short- and long-term gridded climate datasets for the United States. These datasets are provided as `bil` (raster) files and are available for free(!) via FTP at `prism.nacse.org`.  

Because these data, in particular the monthly and daily gridded datasets, are so useful for my work and because extracting over and over from raster files can be computationally costly, I often convert them to either a tabular format (retaining the grid cell information from the rasters) or aggregate them to shapefile boundaries that are more relevant for a given project, such as state, county, or metropolitan areas. This repository holds the code to conduct both of these tasks. In the future, I may add other pieces of code that are also useful for these kinds of tasks.

## Requirements

All code on this repository is in R, and uses `data.table`, `raster` (and maybe `velox`), `sf`, the `tidyverse` and `fst`. 

## A note on directory structure

Because the PRISM files are large, I don't save them to github. Instead, I save them in a separate directory -- on my machine, that's `/data1/prism/raw`, and I save the processed data to `/data1/prism/processed`. You will need to adjust the scripts to suit your needs.

# Thank you

It almost goes without saying, but many thanks to the PRISM group for making these data available. They should be cited as follows, per their [terms of use](http://www.prism.oregonstate.edu/documents/PRISM_terms_of_use.pdf): 

PRISM Climate Group, Oregon State University, http://prism.oregonstate.edu, created 4 Feb 2004.
