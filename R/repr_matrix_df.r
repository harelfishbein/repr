#' Tabular data representations
#' 
#' HTML, LaTeX, and Markdown representations of Matrix-like objects
#' 
#' @param obj  The matrix or data.frame to create a representation for
#' @param ...  ignored
#' @param colspec  The colspec for the LaTeX table. The default is given by the option \code{repr.matrix.latex.colspec}
#' 
#' @seealso \link{repr-options} for \code{repr.matrix.latex.colspec}
#' 
#' @name repr_*.matrix/data.frame
#' @include utils.r
NULL

# There is currently a problem on windows which can't display chars in th
# text/plain output, which are not available in the current locale.
# See https://github.com/IRkernel/repr/issues/28#issuecomment-208574856
#' @importFrom utils capture.output
.char_fallback <- function(char, default) {
  real_len <- nchar(char)
  r_len <- nchar(capture.output(cat(char)))
  if (real_len == r_len) char else default
}
ellip_h <- .char_fallback('\u22EF', '...')
ellip_v <- .char_fallback('\u22EE', '...')
ellip_d <- .char_fallback('\u22F1', '')

# These are used for factor, so make sure they are unique
ellipses <- unique(c(ellip_h, ellip_v, ellip_d))

arr_partition <- function(a, rows, cols) {
	stopifnot(rows >= 2L, cols >= 2L)
	
	many_rows <- rows < nrow(a)
	many_cols <- cols < ncol(a)
	
	# create sequences of indices to bisect rows and columns
	if (many_rows) {
		upper <- seq_len(ceiling(rows / 2))
		lower <- seq.int(nrow(a) - floor(rows / 2) + 1L, nrow(a))
	}
	if (many_cols) {
		left  <- seq_len(ceiling(cols / 2))
		right <- seq.int(ncol(a) - floor(cols / 2) + 1L, ncol(a))
	}
	
	# assign a list of parts that can be coerced to strings
	if (many_rows && many_cols) {
		structure(list(
			ul = a[upper, left],  ll = a[lower, left],
			ur = a[upper, right], lr = a[lower, right]),
		omit = 'both')
	} else if (many_rows) {
		structure(list(
			upper = a[upper, , drop = FALSE],
			lower = a[lower, , drop = FALSE]),
		omit = 'rows')
	} else if (many_cols) {
		structure(list(
			left  = a[, left,  drop = FALSE],
			right = a[, right, drop = FALSE]),
		omit = 'cols')
	} else {
		structure(list(full = a), omit = 'none')
	}
}

arr_parts_format <- function(parts) structure(lapply(parts, arr_part_format), omit = attr(parts, 'omit'))
arr_part_format <- function(part) {
	f_part <- if (is.data.frame(part)) {
		vapply(part, format, character(nrow(part)))
	} else {
		# format(part) would work, but e.g. would left-pad *both* rows of matrix(7:10, 2L) instead of one
		apply(part, 2L, format)
	}
	# vapply returns a vector for 1-column dfs
	dim(f_part) <- dim(part)
	dimnames(f_part) <- dimnames(part)
	f_part
}

#' @importFrom utils head tail
arr_parts_combine <- function(parts, rownms, colnms) {
	omit <- attr(parts, 'omit')
	mat <- switch(omit,
		rows = rbind(parts$upper, ellip_v, parts$lower, deparse.level = 0L),
		cols = cbind(parts$left,  ellip_h, parts$right, deparse.level = 0L),
		none = parts$full,
		both = rbind(
			cbind(parts$ul, ellip_h, parts$ur, deparse.level = 0L),
			c(rep(ellip_v, ncol(parts$ul)), ellip_d, rep(ellip_v, ncol(parts$ur))),
			cbind(parts$ll, ellip_h, parts$lr, deparse.level = 0L)))
	
	# If there were no dimnames before, as is often true for matrices, don't assign them.
	if (omit %in% c('rows', 'both') && !is.null(rownms)) {
		# everything except ellip_v is to fix rownames for tbls, which explicitly set them to 1:n when subsetting
		rownames(mat) <- c(head(rownms, nrow(parts[[1]])), ellip_v, tail(rownms, nrow(parts[[2]])))
	}
	if (omit %in% c('cols', 'both') && !is.null(colnms)) {
		colnames(mat)[[ncol(parts[[1]])  + 1L]] <- ellip_h
	}
	
	mat
}

# returns a character array with optionally a section of columns and rows in the middle replaced by ellipses
ellip_limit_arr <- function(
	a,
	rows = getOption('repr.matrix.max.rows'),
	cols = getOption('repr.matrix.max.cols')
) {
	parts <- arr_partition(a, rows, cols)
	stopifnot(match('ll', names(parts)) %in% c(NA, 2L))  # lower has to come second if available
	f_parts <- arr_parts_format(parts)
	arr_parts_combine(f_parts, rownames(a), colnames(a))
}



# HTML --------------------------------------------------------------------



repr_matrix_generic <- function(
	x,
	wrap,
	header_wrap, corner, head,
	body_wrap, row_wrap, row_head,
	cell,
	escape_fun = identity,
	...,
	rows = getOption('repr.matrix.max.rows'),
	cols = getOption('repr.matrix.max.cols')
) {
	has_rownames <- has_row_names(x)
	has_colnames <- !is.null(colnames(x)) && ncol(x) > 0
	
	if (!has_rownames && !has_colnames && 0L %in% dim(x))
		return('')
	
	# TODO: ineffective to flatten the whole thing
	# But when are we encountering huge nested arrays?
	x <- ellip_limit_arr(flatten(x), rows, cols)
	
	header <- ''
	if (has_colnames) {
		headers <- sprintf(head, escape_fun(colnames(x)))
		if (has_rownames) headers <- c(corner, headers)
		header <- sprintf(header_wrap, paste(headers, collapse = ''))
	}
	
	rows <- lapply(seq_len(nrow(x)), function(r) {
		row <- escape_fun(slice_row(x, r))
		cells <- sprintf(cell, format(row))
		if (has_rownames) {
			row_head <- sprintf(row_head, escape_fun(rownames(x)[[r]]))
			cells <- c(row_head, cells)
		}
		sprintf(row_wrap, paste(cells, collapse = ''))
	})
	
	body <- sprintf(body_wrap, paste(rows, collapse = ''))
	
	sprintf(wrap, header, body)
}


#' @name repr_*.matrix/data.frame
#' @export
repr_html.matrix <- function(obj, ...) repr_matrix_generic(
	obj,
	'<table>\n%s%s</table>\n',
	'<thead><tr>%s</tr></thead>\n', '<th></th>',
	'<th scope=col>%s</th>',
	'<tbody>\n%s</tbody>\n', '\t<tr>%s</tr>\n', '<th scope=row>%s</th>',
	'<td>%s</td>',
	escape_fun = html_escape_vec,
	...)

#' @name repr_*.matrix/data.frame
#' @export
repr_html.data.frame <- repr_html.matrix



# LaTeX -------------------------------------------------------------------



#' @name repr_*.matrix/data.frame
#' @export
repr_latex.matrix <- function(obj, ..., colspec = getOption('repr.matrix.latex.colspec')) {
	cols <- paste0(paste(rep(colspec$col, ncol(obj)), collapse = ''), colspec$end)
	if (!is.null(rownames(obj))) {
		row_head <- colspec$row_head
		if (is.null(row_head)) row_head <- colspec$row.head  # backwards compat
		cols <- paste0(colspec$row_head, cols)
	}
	
	r <- repr_matrix_generic(
		obj,
		sprintf('\\begin{tabular}{%s}\n%%s%%s\\end{tabular}\n', cols),
		'%s\\\\\n\\hline\n', '  &', ' %s &',
		'%s', '\t%s\\\\\n', '%s &',
		' %s &',
		escape_fun = latex_escape_vec,
		...)
	
	#TODO: remove this quick’n’dirty post processing
	gsub(' &\\', '\\', r, fixed = TRUE)
}

#' @name repr_*.matrix/data.frame
#' @export
repr_latex.data.frame <- repr_latex.matrix



# Markdown -------------------------------------------------------------------



#' @name repr_*.matrix/data.frame
#' @export
repr_markdown.matrix <- function(obj, ...) {
	cols <- list(...)$cols
	if (is.null(cols)) cols <- getOption('repr.matrix.max.cols')
	
	obj <- flatten(obj)
	out_cols <- min(ncol(obj), cols + 1L) + as.integer(has_row_names(obj))
	underline <- paste(rep('---', out_cols), collapse = '|')
	
	repr_matrix_generic(
		obj,
		'\n%s%s\n',
		sprintf('|%%s\n|%s|\n', underline), ' <!--/--> |', ' %s |',
		'%s', '|%s\n', ' %s |',
		' %s |',
		escape_fun = identity,  # TODO
		..., cols = cols)
}

#' @name repr_*.matrix/data.frame
#' @export
repr_markdown.data.frame <- repr_markdown.matrix



# Text -------------------------------------------------------------------



#' @name repr_*.matrix/data.frame
#' @importFrom utils capture.output
#' @export
repr_text.matrix <- function(obj, ...) {
	if (inherits(obj, c('tbl', 'data.table'))) {
		# Coerce to data.frame to avoid special printing in dplyr and data.table.
		obj <- as.data.frame(obj)
	}
	limited_obj <- ellip_limit_arr(obj, ...)
	print_output <- capture.output(print(limited_obj, quote = FALSE))
	paste(print_output, collapse = '\n')
}

#' @name repr_*.matrix/data.frame
#' @export
repr_text.data.frame <- repr_text.matrix
