*┌─────────────────────────────────────────────────────────────────────────┐
*│Any time you run this code, make sure you've got the right information in│
*│these first seven macros.  You shouldn't need to change anything else in │
*│the code to make it workable.  It automatically detects which activities │
*│are present in the data.  You just need to tell it where the raw data    │
*│is, timestamp info, how you want it to save the .csv files, and which    │
*│activities only need delivered data.  The code will do the rest of the   │
*│work for you.   Each comment block translates the code following it into │
*│plain English.                                                           │
*└─────────────────────────────────────────────────────────────────────────┘
*┌────────────────────────────────────────────────────────────────────┐
*│This is intended to be a list of all activity codes which have      │
*│corresponding NEM classes.  It will be used when we start exporting.│
*│Make sure this is accurate.                                         │
*└────────────────────────────────────────────────────────────────────┘
local delOnly = "X110 Y705 X100 X062 X101 Y227 Y212 Y266 Y251 X102 X063 Y125 Y213 Y252 Y228 Y267 X093 Y253 Y103 Y233 Y272 X103 X093 Y253 X095"
*┌──────────────────────────────────────────────────────────────┐
*│This is the directory where we will export all our .csv files.│
*└──────────────────────────────────────────────────────────────┘
local stataOutputDir = "M:\Class Load Data - Nevada Power\2020_2022 Class Loads\2- Test Oct 2021_Sept 2022\Small Census_Jan22_Mar22\Kevin Practice\Stata Output\"
*┌──────────────────────────────────────────────────────────────────────────────┐
*│This is the part of the output filenames which comes after the activity codes.│
*└──────────────────────────────────────────────────────────────────────────────┘
local filename_suffix = "_Jan22_Mar22.csv"
*┌───────────────────────────────────────────┐
*│This is the filename to load raw data from.│
*└───────────────────────────────────────────┘
local rawData = "M:\Class Load Data - Nevada Power\2020_2022 Class Loads\2- Test Oct 2021_Sept 2022\Small Census_Jan22_Mar22\BBWR-768_interval_data_Small_Census_Commercial_Jan2022_to_Mar2022.csv"
*┌──────────────────────────────────────────────────────────┐
*│These are the names of the columns containing the interval│
*│start and end timestamps in the raw data.                 │
*└──────────────────────────────────────────────────────────┘
local start_timestamp_column_name = "read_start_timestamp"
local end_timestamp_column_name = "read_end_timestamp"
*┌─────────────────────────────────────────────────────────────────────────┐
*│This is the format of the timestamps in those columns. For more info, run│
*│the command "help clock" - that help file explains how to structure this.│
*└─────────────────────────────────────────────────────────────────────────┘
local timestamp_format = "YMDhms"


*┌─────────────────────────────────────────────────────────────────────────┐
*│First, "fix" the timestamps and produce the dups and minute_diff columns.│
*└─────────────────────────────────────────────────────────────────────────┘
import delimited using "`rawData'", clear
process_time_stamps `end_timestamp_column_name', `timestamp_format'
sort activity unit uxrnetr_esd_config_type datetime
by activity  unit uxrnetr_esd_config_type datetime: gen dups = cond(_N==1, 0, _n)
gen minute_diff = minutes(stamp - clock(`start_timestamp_column_name', "`timestamp_format'"))
*┌───────────────────────────────────────────────────────────────────────┐
*│Now put your eyeballs on the data...  Mostly you're looking to fix DST.│
*└───────────────────────────────────────────────────────────────────────┘
tab minute_diff
tab dups
drop dups minute_diff
*┌─────────────────────────────────────────────────────────────────────────┐
*│Then "clean up" the data a bit, and save it with the datesFixed filename.│
*└─────────────────────────────────────────────────────────────────────────┘
drop if unit == "KVARH_DEL" | unit == "KVARH_REC"
drop if uxrnetr_esd_config_type != "NULL"
*( This is commented out, because it's not even necessary to save this file anymore.  )
*( We only saved it with the standard code so we could then load it like fifty times. )
*save "`datesFixed'", replace
*┌─────────────────────────────────────────────────────────────────────────┐
*│Now check to see what activity codes are in the dataset.  This feels out │
*│of place here, but we need to do it before the reshape, for efficiency.  │
*└─────────────────────────────────────────────────────────────────────────┘
levelsof activity
local activities = `"`r(levels)'"'
local activities : list clean activities
display "`activities'"
*┌────────────────────────────────────────────────────┐
*│Create and store a reshaped dataset with usage data.│
*└────────────────────────────────────────────────────┘
preserve
gen colName = activity + "_total_" + strlower(unit)
keep stamp year month day hour minute colName usage
order stamp year month day hour minute colName usage
reshape wide usage, i(stamp year month day hour minute) j(colName) string
rename usage* *
tempfile usageFile
save `usageFile'
*┌────────────────────────────────────────────────────┐
*│Now create a reshaped dataset with customer counts. │
*└────────────────────────────────────────────────────┘
restore
gen colName = activity + "_countofrdps" + strlower(substr(unit, 4, 4))
keep stamp year month day hour minute colName distinct_count_of_rdp
order stamp year month day hour minute colName distinct_count_of_rdp
rename distinct_count_of_rdp _
reshape wide _, i(stamp year month day hour minute) j(colName) string
rename _* *
*┌─────────────────────────────────────────────────────────────────────────┐
*│Then merge the two datasets.  Also, grab a list of all column names in   │
*│the dataset.                                                             │
*└─────────────────────────────────────────────────────────────────────────┘
merge 1:1 stamp using `usageFile'
drop _merge
ds *
local columns_in_dataset = "`r(varlist)'"
display "`columns_in_dataset'"


*┌──────────────────────────────────────────────────────────────────────┐
*│Now start exporting csv files.  The below code will cycle through once│
*│for every activity in the dataset.                                    │
*└──────────────────────────────────────────────────────────────────────┘
foreach activity in `activities' {
*┌───────────────────────────────────────────────────┐
*│First, check if the activity requires gen and rec. │
*└───────────────────────────────────────────────────┘
    local gen_rec : list activity in delOnly
    local gen_rec = !`gen_rec'
*┌───────────────────────────────────────────────────────────────────┐
*│If it does, then make a list of columns including del, gen and rec.│
*└───────────────────────────────────────────────────────────────────┘
    local columns = "stamp year month day hour minute"
    if `gen_rec' {
        foreach unit in del gen rec {
            local columns = "`columns'" + " " + "`activity'_total_kwh_`unit'"
            local columns = "`columns'" + " " + "`activity'_countofrdps_`unit'"
        }
    }
*┌─────────────────────────────────────────────────────────────────────────┐
*│If it doesn't, then make a list of columns without gen and rec, just del.│
*└─────────────────────────────────────────────────────────────────────────┘
    else {
        local columns = "`columns'" + " " + "`activity'_total_kwh_del"
        local columns = "`columns'" + " " + "`activity'_countofrdps_del"
    }
    display "`columns'"
*┌─────────────────────────────────────────────────────────────────────────────┐
*│Importantly, check to see if the columns we've listed are in the dataset.    │
*│If not, then this command will remove the missing column names from the list.│
*│This might be necessary if a customer class which requires gen and rec       │
*│didn't have any customers report nonzero gen or rec for the entire time      │
*│period of our data (BDP will omit, instead of putting zeros).                │
*└─────────────────────────────────────────────────────────────────────────────┘
    local columns : list columns & columns_in_dataset
*┌──────────────────────────────────┐
*│Now we make a filename for export.│
*└──────────────────────────────────┘
    local csvFilename = "`stataOutputDir'" + "`activity'" + "`filename_suffix'"
    display "`csvFilename'"
*┌─────────────────────────────────────────────────────────────────┐
*│Then we export only the columns we have in the list we just made.│
*└─────────────────────────────────────────────────────────────────┘
    export delimited `columns' using "`csvFilename'"
}
*┌────────────────────────────────────────────────────────────────────────┐
*│Here we finish the loop code, so this is where we will go back to the   │
*│"foreach" statement on line #108, and repeat the loop with the next     │
*│activity code.  This cycle repeats until we've done all activities.     │
*│                                                                        │
*│HINT: If you'd like to step through the code in this loop line-by-line, │
*│that can be done easily.  You just need to put a local macro in your    │
*│Stata console called "activity" - do that with this command:            │
*│                                                                        │
*│                   local activity = "X200"                              │
*│                                                                        │
*│(I've used "X200" as an example, you'll want to pick an activity in your│
*│actual dataset.)  Once that macro is in your console, you'll be able to │
*│run all the code in this loop starting at the first line.  You can do   │
*│the same thing with the loop on line #119, when you get there.  Just use│
*│                                                                        │
*│                   local unit = "del"                                   │
*│                                                                        │
*│Remember you'll want to repeat the code after setting local unit="gen"  │
*│and also local unit="rec" before moving forward past that smaller loop. │
*│Otherwise you won't really be seeing what the code does, only what it   │
*│would do if it wasn't a loop.                                           │
*│                                                                        │
*│If you're stepping through this process and you want to see what it's   │
*│changing, then the "display" command is your best friend.  To display   │
*│the contents of a local macro, for example you will probably want to    │
*│see the contents of the "columns" macro in this loop, so to do that, run│
*│                                                                        │
*│                   display "`columns'"                                  │
*│                                                                        │
*│You can do this with any macro name, so to see the contents of the      │
*│"activity" macro (the base macro for this loop), just type              │
*│                                                                        │
*│                   display "`activity'"                                 │
*│                                                                        │
*│One final note - if you are having trouble getting this display command │
*│to work right, pay very close attention to the single quotes.  The one  │
*│on the left is different from the one on the right.  The one on the left│
*│is what you get when you press the button to the left of the number 1 on│
*│an American keyboard.  It's called a "backtick".  The one on the right  │
*│is just a regular apostrophe (a "lowercase quote").  This seems like    │
*│it's unnecessarily complicated, but there is a very good reason Stata   │
*│uses this scheme.                                                       │
*└────────────────────────────────────────────────────────────────────────┘