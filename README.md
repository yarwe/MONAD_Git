Here is an explanation of the different pieces of code in this project.

Organization of code and related functions:
Generally, they are organized using a number at the end (10, 11, 20...).
The first number is the stage of the code (10 is the first code to run, then 20).
the next numbers are sub-codes related to the main code in that series. So, for example, SetupEnviroment11 is a function related to the main code of 10.


Explanation on the different pieces of code in order of running:

	- preproc10: first code to run. 
	  Starts with loading an environment using setupEnviroment11(), which loads the paths, loads fieldtrip etc. and general variables.
	  the data is loaded using load_data12() which contains the variables for loading data from each dataset (paths, file type etc.)
	  First you do a general prepressing (demean, detrend, filters...).
	  Then moves to automatic Z artifact removal which identifies abnormal peaks in the data and removes them.
	  Then there is a manual inspection of the data to identify further artifacts and bad channels.
	  Artifacts are removed and bad channels are interpolated using fixChannels14().
	  Along the code, a CSV file is created to document the different stages - which filters were used, which channels were interpolated etc.
	  A new line for a participant is added to the CSV using csv_init15(), and the line is updated using csv_addcol16().

	- freq_analysis20: second code to run. 
	  Choose the desired variables for calculating the LAVI into Lcfg and for calculating the FFT into Fcfg.
	  Then, you can compute the LAVI and create a (or add to an existing) data frame containing the LAVI calculations of all the participants 
	  using create_datArr21().
	  You can either calculate the LAVI of specific participants and add it to an existing data frame by putting cfg.prev = 'add',
	  or calculate the LAVI across all clean datasets using cfg.prev = 'all'.
	  If you already have the dataframe containing all the LAVI computations jump to the cell to load it.
	  Then you can compute the peaks in the LAVI spectrum and plot it.

 * user_func: This function contains the name of the user and the letter of the DataAyelet folder on your computer. 
   According to the name provided in the user variable, the paths are adapted in the setupEnviroment11() function.
   This is instead of changing it within the code each time, allowing for more comfortable sharing of code using github.
