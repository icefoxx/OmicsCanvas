#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin R Template V1.0
# ------------------------------------------------------------
# Purpose:
#   A standard R template for BioFigureAI plot plugins.
#
# Runtime contract:
#   Rscript plot.R \
#     --input input.csv \
#     --params params.json \
#     --output output_dir
#
# Expected outputs:
#   output_dir/result.svg
#   output_dir/result.pdf     optional but recommended
#   output_dir/result.png     optional
#   output_dir/figure.json    recommended for future editor and AI actions
#   output_dir/run.log        recommended
#   output_dir/error.json     generated on failure
#
# Notes for Agent:
#   Replace the section marked "PLUGIN-SPECIFIC LOGIC" with the actual plotting logic.
#   Keep the command-line interface, error handling, and output conventions unchanged.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

# ------------------------------------------------------------
# 1. Parse command line arguments
# ------------------------------------------------------------
option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Path to the main input file, usually CSV/TSV/TXT.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))

input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

# ------------------------------------------------------------
# 2. Helper functions
# ------------------------------------------------------------
write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  error_obj <- list(
    error = error,
    detail = ifelse(is.null(detail), '', detail),
    suggestion = ifelse(is.null(suggestion), '', suggestion)
  )

  writeLines(
    jsonlite::toJSON(error_obj, auto_unbox = TRUE, pretty = TRUE),
    file.path(output_dir, 'error.json')
  )

  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit(
      error = 'Input file not found',
      detail = paste('Input path:', path),
      suggestion = 'Please provide a valid input file path.'
    )
  }

  ext <- tolower(tools::file_ext(path))

  if (ext %in% c('csv')) {
    return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  }

  if (ext %in% c('tsv', 'txt')) {
    return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  }

  write_error_and_exit(
    error = 'Unsupported input file type',
    detail = paste('File extension:', ext),
    suggestion = 'For MVP, use csv, tsv, or txt input files.'
  )
}

get_param <- function(params, name, default = NULL) {
  if (!is.null(params[[name]])) {
    return(params[[name]])
  }
  default
}

validate_columns <- function(df, cols) {
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit(
      error = 'Required input columns not found',
      detail = paste('Missing columns:', paste(missing_cols, collapse = ', ')),
      suggestion = 'Please check column mapping in config.yaml and params.json.'
    )
  }
}

# ------------------------------------------------------------
# 3. Validate runtime inputs
# ------------------------------------------------------------
if (is.null(input_file)) {
  write_error_and_exit('Missing --input argument')
}

if (is.null(params_file) || !file.exists(params_file)) {
  write_error_and_exit(
    error = 'Params file not found',
    detail = paste('Params path:', params_file),
    suggestion = 'Backend should generate params.json and pass it through --params.'
  )
}

if (is.null(output_dir)) {
  write_error_and_exit('Missing --output argument')
}

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

write_log('Plugin started.')

# ------------------------------------------------------------
# 4. Load params and input data
# ------------------------------------------------------------
params <- tryCatch(
  jsonlite::fromJSON(params_file),
  error = function(e) {
    write_error_and_exit(
      error = 'Failed to parse params.json',
      detail = conditionMessage(e),
      suggestion = 'Please make sure params.json is valid JSON.'
    )
  }
)

write_log('Loaded params.json.')

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input table with %s rows and %s columns.', nrow(df), ncol(df)))

# ------------------------------------------------------------
# 5. Common plotting parameters
# ------------------------------------------------------------
title <- get_param(params, 'title', 'BioFigureAI Plot')
width <- as.numeric(get_param(params, 'width', 7))
height <- as.numeric(get_param(params, 'height', 6))
theme_name <- get_param(params, 'theme', 'default')

# Standard column mapping names.
# Agent should update these defaults according to plugin type.
x_column <- get_param(params, 'x_column', NULL)
y_column <- get_param(params, 'y_column', NULL)
color_column <- get_param(params, 'color_column', NULL)

# ------------------------------------------------------------
# 6. PLUGIN-SPECIFIC LOGIC
# ------------------------------------------------------------
# Agent instructions:
#   Replace this block with the actual plot logic for the plugin.
#   Keep outputs as result.svg, result.pdf, and figure.json.
#   Do not hard-code local paths.
#   Do not write output outside output_dir.
#   Validate all required columns before plotting.

if (is.null(x_column) || is.null(y_column)) {
  numeric_cols <- names(df)[sapply(df, is.numeric)]
  if (length(numeric_cols) >= 2) {
    x_column <- numeric_cols[1]
    y_column <- numeric_cols[2]
  } else {
    write_error_and_exit(
      error = 'No valid x/y columns provided',
      detail = 'x_column and y_column are missing, and fewer than two numeric columns were found.',
      suggestion = 'Provide x_column and y_column in params.json or upload a table with at least two numeric columns.'
    )
  }
}

validate_columns(df, c(x_column, y_column))

if (!is.null(color_column) && color_column %in% colnames(df)) {
  p <- ggplot(df, aes(x = .data[[x_column]], y = .data[[y_column]], color = .data[[color_column]])) +
    geom_point(size = as.numeric(get_param(params, 'point_size', 1.5)), alpha = as.numeric(get_param(params, 'alpha', 0.8)))
} else {
  p <- ggplot(df, aes(x = .data[[x_column]], y = .data[[y_column]])) +
    geom_point(size = as.numeric(get_param(params, 'point_size', 1.5)), alpha = as.numeric(get_param(params, 'alpha', 0.8)))
}

p <- p +
  labs(title = title, x = x_column, y = y_column) +
  theme_classic()

# Optional theme hook. Keep simple in V1.
if (theme_name == 'minimal') {
  p <- p + theme_minimal()
}

# ------------------------------------------------------------
# 7. Write outputs
# ------------------------------------------------------------
svg_file <- file.path(output_dir, 'result.svg')
pdf_file <- file.path(output_dir, 'result.pdf')
png_file <- file.path(output_dir, 'result.png')
figure_json_file <- file.path(output_dir, 'figure.json')

tryCatch({
  ggsave(svg_file, p, width = width, height = height, device = 'svg')
  ggsave(pdf_file, p, width = width, height = height, device = 'pdf')
  ggsave(png_file, p, width = width, height = height, dpi = 300)
}, error = function(e) {
  write_error_and_exit(
    error = 'Failed to save plot outputs',
    detail = conditionMessage(e),
    suggestion = 'Check plotting code, output directory permissions, and graphics device support.'
  )
})

figure_json <- list(
  figure_type = get_param(params, 'plugin_id', 'generic_plot'),
  title = title,
  theme = theme_name,
  layout = list(
    width = width,
    height = height
  ),
  data = list(
    input_file = basename(input_file),
    n_rows = nrow(df),
    n_columns = ncol(df)
  ),
  layers = list(
    list(id = 'points', type = 'scatter', editable = TRUE),
    list(id = 'title', type = 'text', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE)
  ),
  export = list(
    svg = 'result.svg',
    pdf = 'result.pdf',
    png = 'result.png'
  )
)

writeLines(
  jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE),
  figure_json_file
)

write_log('Plugin completed successfully.')
quit(status = 0)
