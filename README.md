For the script to work different requirements need to match
- All inputs need to be csv-files
- only include the raw data and header, remove other all other things! 
- If different plates are stored in one file, remove all other plates!

The plate reader file:
- Use of a plate reader with columns of at least Well,Signal,

The dispenser file:
- Is probably very different from dispenser to dispenser (here D300e from Tecan was used)
- Important columns: Dispensed well, Fluid name, Dispensed concentration, Units
- In case of problems with other dispensers the script needs to be updated

Input:
- Plate reader file
- Dispenser file

Output:
- List of processed data
- PDF of graphics from processed data

- In the script a seaborn matrix is created -> check there if the data looks as expected

Aside that the script is customziable:
- FILE_PLATE_READER -> Name of the plate reader file
- FILE_DISPENSER    -> Name of the dispenser file
- FILE_OUTPUT       -> Name of processed data as a list
- PDF_FILE_OUTPUT   -> Name of the pdf file with all graphics
- RSCRIPT_PATH      -> Own pathway where Rscripts are stored!

- POSITIVE_CONTROLS -> Name of positive control        
- NEGATIVE_CONTROLS -> Name of negative contr    
- REMOVE_LIST       -> Name of the things to remove! Leave 'Evaporation_Control', as it throughs out all rows without interest

- ANCHOR_DRUG       -> Drug one axis    
- PARTNER_DRUG      -> Drug other axis     

- TARGET_BINS       -> Concentrations of the two drugs, put all in one list and use 0.00 as well
- REMOVE_CONCENTRATIONS -> If some concentrations look like outlier you can remove them again here
