# Project Structure and Execution Guide

## Project Template Overview

This project is organized with the following structure:

- **reports:**
  - `TeraScope_Report.pdf`: Main report file containing the analysis details.
  - `TeraScope_Report.Rmd`: Rmarkdown version of the analysis report containing all the code to generate the pdf.
  - `Abstract.pdf`: The report which contains the abstract along with the 2 images.

- **log:**
  - `Gitlog.txt`: Git log file capturing version control history.

- **munge:**
  - `01-A.R`: R script file which contains the code been used for data manipulation.

- **data**
  - Contains the data needed for the analysis.

## Running the Analysis

### 1. Install R and RStudio
   Ensure you have the latest versions of R and RStudio installed on your computer.

### 2. Install 'patchwork' library
   For some visualisations in the report patchwork library have been used, make sure you have installed it before you proceed.
   
   Use the following R code within RStudio:
   ```R
   install.packages("patchwork")
   ```
   
### 3. Install LaTeX (if needed)
   If LaTeX is not installed on your system, you may need to install it before knitting the report in order to generate the pdf version of it.

   Use the following R code within RStudio:
   ```R
   install.packages("tinytex")
   tinytex::install_tinytex()
   ```
### 4. Set Working Directory
   Open RStudio and set the working directory to the main folder of the project (`Terascope_Performance`).

### 5. Adding the data
   Add the following `csv` files to the `data` folder of the project:
   
   - application-checkpoints.csv
   - gpu.csv
   - task-x-y.csv

### 6. Open and Run the Analysis Report
   - Navigate to the `reports` folder.
   - Open the `TeraScope_Report.Rmd` file.
   - Press the "Knit" button in RStudio to execute the analysis.
   - The analysis report will be generated and displayed in your browser.

### 7. Open and Run the Abstract Report
   - Navigate to the `reports` folder.
   - Open the `Abstract.Rmd` file.
   - Press the "Knit" button in RStudio to execute the abstract.
   - The abstract report will be generated and displayed in your browser.


For more details about ProjectTemplate, see http://projecttemplate.net