# All code contained in this repository is the original work of Kevin Bumgartner.  It is provided
# here only for demonstration purposes, and it is not provided with any explicit or implicit
# permission to use the code for any purpose other than demonstration that the code works.

# The code in this file does some data mining on datasets available freely from the
# Bureau of Labor Statistics.  The information was the subject of an Econometrics
# project.  The dataset has no missing data, but it is organized in a haphazard manner.
# My goal in writing this code was to arrange the data in such a way as to make it
# possible to analyze.  The datasets used are available at the URLs:
# https://www.bls.gov/tus/special.requests/atusresp_2010.zip
# https://www.bls.gov/tus/special.requests/atusact_2010.zip
# In the file atusresp_2010.dat, there is information about survey respondents, each
# identified by a key column called TUCASEID.  In the file atusact_2010.dat, there is
# information gathered from respondents on different days, coding their use of time
# throughout the day by activity.  The code I've written here pulls the information
# from the atusact_2010.dat file and assembles it in the form of means and counts, 
# assigning it to the rows of the atusresp_2010.dat file by TUCASEID, so that the mean
# time use data can be analyzed along with the respondent data all in one dataframe.

library(data.table)

#The following code loads the datasets.
data <- data.table(read.csv(’atusresp_2010.dat’))
rawdata <- data.table(read.csv(’atusact_2010.dat’))

#This function takes in three vectors. The vectors must be the same length.
#The first is a vector of strings, the second and third are vectors indicating
#the code range of where the column’s activities are found.

mineColumns <- function(colname, begincode, endcode, rawData, data){

#The first line here is an lapply() - its output is a list of data.tables.
	tableList <- lapply(1:length(colname), function(i){
				out <- rawData[TRCODE %in% begincode[i]:endcode[i],
						mean(TUACTDUR), TUCASEID]
				setnames(out, old="V1", new=paste0(colname[i],"_AVG"))
				out[,paste0(colname[i],"_COUNT") := rawData[TRCODE %in%
					begincode[i]:endcode[i], length(TUACTDUR), TUCASEID]$V1]
				out
			})

#This snippet combines all of the data.tables from the list we just made. In order
#to accomplish this efficiently, we use Reduce() - but Reduce needs a binary
#function to apply. So we make one out of merge() here.
	binaryMerge <- function(dt1, dt2){
		merge(dt1, dt2, by="TUCASEID", all=TRUE)
	}
	data <- Reduce(binaryMerge, tableList, data)

#Finally we clean up. Here, we’ve produced a lot of NAs where they don’t belong.
#Any of the NAs in the columns we’ve produced should actually be zeros. So we’ll
#go through and make them all zeros.
	columnsAdded <- c(paste0(colname, "_AVG"), paste0(colname, "_COUNT"))
	for (col in columnsAdded){
		logVect <- is.na(data[[col]])
		if (sum(logVect)>0) data[logVect, ][[col]] <- 0
	}
	data
}

#Having put together our scaffolding, here we assemble some column names. Each
#column has a beginning code and an ending code in the lexicon. So we provide
#those codes in the vectors begincode and endcode.
columns <- c("RELIGION", "DRIVING4WORK", "WORKING", "CAR_STUFF",
		"YARD_WORK", "APPEARANCE", "ANIMAL_CARE", "CHILD_CARE",
		"HOUSEWORK", "WORKING_OUT")
begincode <- c(140100, 180500, 50100, 20700,
		20500, 10200, 20600, 30100,
		20100, 130100)
endcode <- c(149999, 180599, 50199, 20799,
		20599, 10299, 20699, 30399,
		20299, 130199)


#Finally we actually run the mining operation.
data <- mineColumns(columns, begincode, endcode, rawdata, data)

# All code contained in this repository is the original work of Kevin Bumgartner.  It is provided
# here only for demonstration purposes, and it is not provided with any explicit or implicit
# permission to use the code for any purpose other than demonstration that the code works.
