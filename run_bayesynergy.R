# --- run_bayesynergy.R ---

args <- commandArgs(trailingOnly=TRUE)
INPUT_FILE    <- args[1]  
ANCHOR_DRUG   <- args[2]  
PARTNER_DRUG  <- args[3]  
CUSTOM_NAME   <- args[4]  
READOUT_LABEL <- args[5]  
HEATMAP_COLOR <- args[6]  

# Fallbacks just in case the arguments are missing
if (is.na(READOUT_LABEL) || READOUT_LABEL == "") READOUT_LABEL <- "Viability [%]"
if (is.na(HEATMAP_COLOR) || HEATMAP_COLOR == "") HEATMAP_COLOR <- "plasma"

# Load required libraries
suppressPackageStartupMessages(library(bayesynergy))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(scales)) 
suppressPackageStartupMessages(library(grid))

df <- read.csv(INPUT_FILE)

# =====================================================================
# 1. GENERATE THE SEABORN-STYLE HEATMAP IN R
# =====================================================================
agg_df <- aggregate(Viability_pct ~ Conc1 + Conc2, data = df, FUN = mean)

heatmap_plot <- ggplot(agg_df, aes(x = factor(Conc1), y = factor(Conc2), fill = Viability_pct)) +
  geom_tile(color = "white", size = 0.5) +
  
  # Text inside the boxes
  geom_text(aes(label = sprintf("%.1f", Viability_pct)), 
            color = ifelse(agg_df$Viability_pct < 40, "white", "black"), size = 4.5) +
  
  # Dynamic Color and Label applied here:
  scale_fill_viridis_c(option = HEATMAP_COLOR, name = READOUT_LABEL, 
                       limits = c(0, 100), oob=squish) +
  
  labs(x = paste(ANCHOR_DRUG, "[µM]"), y = paste(PARTNER_DRUG, "[µM]")) +
  theme_minimal()

# =====================================================================
# 2. RUN BAYESYNERGY MODEL
# =====================================================================
y <- df$Viability_pct / 100
x <- as.matrix(df[, c("Conc1", "Conc2")])

cat(paste("\n[R] Running Bayesynergy for:", ANCHOR_DRUG, "+", PARTNER_DRUG, "...\n"))
fit <- bayesynergy(
  y = y, 
  x = x,
  drug_names = c(ANCHOR_DRUG, PARTNER_DRUG),
  method = "sampling" 
)

# =====================================================================
# 3. EXPORT 8:6 PDF (WITH IN-MEMORY GRID GRAPHICS HACK)
# =====================================================================
if (CUSTOM_NAME == "DEFAULT" || is.na(CUSTOM_NAME) || CUSTOM_NAME == "") {
  file_base <- paste0("Report_", ANCHOR_DRUG, "_vs_", PARTNER_DRUG)
} else {
  file_base <- paste0(CUSTOM_NAME, "_Report_", ANCHOR_DRUG, "_vs_", PARTNER_DRUG)
}

output_pdf <- paste0(file_base, ".pdf")

# Standard PDF creation (no weird compression settings needed)
pdf(output_pdf, width=8, height=6, pointsize=16)

# 1. Print the custom heatmap (Page 1)
print(heatmap_plot)  

# 2. GGPLOT2 FONTS
theme_set(theme_bw(base_size = 14) + 
          theme(axis.text = element_text(size = 14),
                axis.title = element_text(size = 16, face="bold"),
                strip.text = element_text(size = 14),
                legend.text = element_text(size = 9),       
                legend.title = element_text(size = 11),     
                legend.key.height = unit(0.4, "cm")))       

# 3. BASE R SCALES
par(cex.axis = 1.15, cex.lab = 1.1)

# 4. Print the Bayesynergy plots (Page 2)
plot(fit)            

# --- THE NEW APPROACH: INTERCEPT THE GRAPHICS IN MEMORY ---
cat("\n[R] Applying Grid Graphics Hack to fix the legend typo and bracket...\n")
try({
  grid.force() # Force R to expose all the hidden graphical objects on the page
  
  # Get a list of every single graphical object currently drawn
  grob_names <- grid.ls(print = FALSE)$name
  
  for (g in grob_names) {
    grb <- tryCatch(grid.get(g), error = function(e) NULL)
    
    # If the object is text and contains the typo
    if (!is.null(grb) && !is.null(grb$label)) {
      if (any(grepl("-0.9", grb$label))) {
        
        # 1. Replace the hard bracket AND the number at the same time
        new_label <- gsub("\\[-100,-0\\.9\\]", "(-100,-90]", grb$label)
        new_label <- gsub("\\[-100, -0\\.9\\]", "(-100, -90]", new_label)
        
        # 2. Catch-all just in case the string is slightly different
        new_label <- gsub("-0\\.9", "-90", new_label) 
        
        # 3. Overwrite the graphic object live on the page!
        grid.edit(g, label = new_label, global = TRUE)
      }
    }
  }
}, silent = TRUE)

# 5. Save the PDF!
dev.off() 

cat(paste("[R] Success! Final corrected PDF saved as:", output_pdf, "\n"))

# =====================================================================
# 4. EXPORT RAW NUMBERS & CHEAT SHEET
# =====================================================================
cat("\n[R] Extracting numerical matrices and statistics for output...\n")

# A. Save the overall summary statistics WITH an embedded Cheat Sheet!
try({
  txt_summary <- paste0(file_base, "_Summary_Statistics.txt")
  
  # Capture the raw math text
  summary_text <- capture.output(summary(fit))
  
  # --- BULLETPROOF FIND AND REPLACE ---
  # Scrub out the bugged bayesynergy names entirely
  summary_text <- gsub(paste0("_", ANCHOR_DRUG), "", summary_text)
  summary_text <- gsub(paste0("_", PARTNER_DRUG), "", summary_text)
  
  # Attach the correct drug names
  summary_text <- gsub("_1\\b", paste0("_", ANCHOR_DRUG), summary_text)
  summary_text <- gsub("_2\\b", paste0("_", PARTNER_DRUG), summary_text)
  summary_text <- gsub("\\[1\\]", paste0("_", ANCHOR_DRUG), summary_text)
  summary_text <- gsub("\\[2\\]", paste0("_", PARTNER_DRUG), summary_text)
  
  # Create the Plain English Cheat Sheet Header
  header_text <- c(
    "==================================================================",
    "BAYESYNERGY CHEAT SHEET (HOW TO READ THESE NUMBERS)",
    "==================================================================",
    "1. THE VUS SCORES (Volume Under the Surface)",
    "   These scores evaluate the entire 3D landscape of your plate.",
    "   - rVUS_f:    ACTUAL average cell survival (Lower is better killing)",
    "   - rVUS_p0:   EXPECTED average cell survival if drugs didn't interact",
    "   - VUS_Delta: NET AVERAGE SYNERGY SCORE (Expected - Actual)",
    "                * Positive (+) = % MORE cells killed (Synergy)",
    "                * Negative (-) = % FEWER cells killed (Antagonism)",
    "",
    "2. THE MONOTHERAPY PARAMETERS",
    "   - la:    Max Efficacy (0 = 100% kill; 0.4 = 40% survive)",
    "   - log10_ec50: The log10 concentration needed to reach half max power",
    "   - slope: How steep the dose-response curve is",
    "",
    "3. HEALTH CHECKS",
    "   - Rhat: Algorithm health. MUST be ~1.00 (If > 1.05, the math struggled)",
    "   - sigma_f: Background noise/error on the plate",
    "==================================================================\n",
    "RAW MODEL OUTPUT:",
    "------------------------------------------------------------------"
  )
  
  # Save the Cheat Sheet + the modified text to the file
  writeLines(c(header_text, summary_text), con = txt_summary)
  cat(paste("  -> Saved Summary:", txt_summary, "\n"))
}, silent = TRUE)

# B. Extract the high-resolution modeled surfaces safely
if ("estimates" %in% names(fit)) {
  for (mat_name in names(fit$estimates)) {
    mat <- fit$estimates[[mat_name]]
    
    # Check if it has rows and columns (2D matrix)
    if (!is.null(dim(mat)) && length(dim(mat)) == 2) {
      csv_filename <- paste0(file_base, "_Matrix_", mat_name, ".csv")
      
      # FORCE it into a data.frame so R writes it perfectly to CSV
      write.csv(as.data.frame(mat), file = csv_filename, row.names = TRUE)
      cat(paste("  -> Saved Matrix:", csv_filename, "\n"))
    }
  }
} else {
  # Fallback for older versions of bayesynergy
  for (mat_name in c("viability", "synergy", "hsa", "bliss", "loewe", "zip")) {
    if (mat_name %in% names(fit)) {
      mat <- fit[[mat_name]]
      if (!is.null(dim(mat)) && length(dim(mat)) == 2) {
        csv_filename <- paste0(file_base, "_Matrix_", mat_name, ".csv")
        write.csv(as.data.frame(mat), file = csv_filename, row.names = TRUE)
        cat(paste("  -> Saved Matrix:", csv_filename, "\n"))
      }
    }
  }
}

