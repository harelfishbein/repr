# override utils:::print.help_files_with_topic

#' Representations of help
#' 
#' @param obj  Help topic to create a representation for
#' @param ...  ignored
#' 
#' @name repr_*.help_files_with_topic
NULL



# copy of utils:::.getHelpFile, necessary because CRAN doesn’t like us using :::
get_help_file <- function(file)
{
	path <- dirname(file)
	dirpath <- dirname(path)
	if(!file.exists(dirpath))
		stop(gettextf("invalid %s argument", sQuote("file")), domain = NA)
	pkgname <- basename(dirpath)
	RdDB <- file.path(path, pkgname)
	if(!file.exists(paste(RdDB, "rdx", sep = ".")))
		stop(gettextf("package %s exists but was not installed under R >= 2.10.0 so help cannot be accessed", sQuote(pkgname)), domain = NA)
	# Alternative position for tools may neeed to be specified as in renjin build fails with "ERROR: Object 'fetchRdDB' not found"
	pos <- -1
	fetch_rd_db <- getFromNamespace('fetchRdDB', 'tools', pos)
	fetch_rd_db(RdDB, basename(file))
}



#' @importFrom utils capture.output
#' @importFrom tools Rd2HTML
repr_help_files_with_topic_generic <- function(obj, Rd2_) {
	topic <- attr(obj, 'topic')
	#type <- attr(obj, 'type') #should we make this html by setting some option?
	#tried_all_packages <- attr(obj, 'tried_all_packages')
	#TODO: handle tried_all_packages
	
	paths <- as.character(obj)
	
	if (length(paths) == 0) {
		return(paste(gettextf('No documentation for %s in specified packages and libraries:', sQuote(topic)),
		             gettextf('you could try %s', sQuote(paste0('??', topic))), sep = '\n'))
	}
	
	#TODO: handle multiple
	file <- paths[[1]]
	
	pkgname <- basename(dirname(dirname(file)))
	
	rd <- get_help_file(file)
	
	output <- capture.output(Rd2_(rd, package = pkgname, outputEncoding = 'UTF-8'))
	
	if (identical(Rd2_, Rd2HTML)) {
		head.end.idx <- which(output == '</head><body>')
		body.end.idx <- which(output == '</body></html>')
		rm.idx <- c(seq_len(head.end.idx), body.end.idx)
		
		output <- output[-rm.idx]
	}
	
	#TODO: replace all the Rd-specific envs in latex
	
	paste(output, collapse = '\n')
}

#' @name repr_*.help_files_with_topic
#' @importFrom tools Rd2txt
#' @export
repr_text.help_files_with_topic <- function(obj, ...)
	repr_help_files_with_topic_generic(obj, Rd2txt)

#' @name repr_*.help_files_with_topic
#' @importFrom tools Rd2HTML
#' @export
repr_html.help_files_with_topic <- function(obj, ...)
	repr_help_files_with_topic_generic(obj, Rd2HTML)

#TODO: markdown

#' @name repr_*.help_files_with_topic
#' @importFrom tools Rd2latex
#' @export
repr_latex.help_files_with_topic <- function(obj, ...)
	repr_help_files_with_topic_generic(obj, Rd2latex)
