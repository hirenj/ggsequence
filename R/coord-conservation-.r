require(grid)

coord_conservation <- function(alignment_axis=TRUE,conservation_axis=TRUE) {
  ggproto(NULL, CoordConservation,
    limits = list(x = NULL, y = NULL),
    expand = TRUE,
    default = FALSE,
    clip = "on",
    alignment_axis = alignment_axis,
    conservation_axis = conservation_axis
  )
}

draw_conservation_grobs <- function(conservation) {
  # gTree(children=gList(
  # grid::rectGrob(
  #   0, 0,
  #   width = 1,
  #   height = grid::unit(2*.pt,"mm"),
  #   default.units = "native",
  #   just = c("left", "top"),
  #   gp = grid::gpar(
  #     #fill = alpha("black", 0.1+seq(0,0.9,by=0.3)),
  #     fill = alpha("black",0),
  #     col='red',
  #     lwd = 1,
  #     lineend = "butt"
  #   )
  # ), // OTHER GROB HERE)
  
  grid::rectGrob(
    conservation$x - 0.5*conservation$width, 0,
    width = conservation$width,
    height = grid::unit(2*.pt,"mm"),
    default.units = "native",
    just = c("left", "top"),
    gp = grid::gpar(
      fill = alpha("black",0.1+conservation$value*0.9),
      col='black',
      lwd = 0.3,
      lineend = "butt"
    )
  )
}

get_conservation_from_scale <- function(scale_obj) {
  cons=attributes(scale_obj$scale)$conservation
  limits=c( min(scale_obj$limits), max(scale_obj$limits))
  rescaler=scale_obj$rescale
  if (limits[1] < 1) {
    limits[1] = 1
  }
  if (limits[2] > length(cons)) {
    limits[2] = length(cons)
  }
  wanted_cons = cons[limits[1]:limits[2]]
  x = sapply( limits[1]:limits[2], rescaler )
  return( data.frame( x = x, value = wanted_cons, width=rescaler(2)-rescaler(1) ))
}

get_aa_indexes_from_scale <- function(scale_obj) {
  indexes = attributes(scale_obj$scale)$aligned_indexes
  limits=c( min(scale_obj$limits), max(scale_obj$limits))
  rescaler=scale_obj$rescale
  breaks = scale_obj$get_breaks()
  break_size = 10
  if (length(breaks) > 1) {
    break_size = breaks[2] - breaks[1]
  }
  indexes_breaks = lapply(indexes, function(seq_idxs) {
    seq_idxs = setNames(seq_idxs,1:length(seq_idxs))
    seq_idxs = seq_idxs[seq_idxs >= limits[1] & seq_idxs <= limits[2]]
    wanted_indexes = seq(0,max(as.numeric(names(seq_idxs))),by=break_size)
    wanted_positions = rescaler(seq_idxs[wanted_indexes[wanted_indexes > 0]])
    data.frame(x=wanted_positions,label=names(wanted_positions))
  })
  indexes_breaks
}

draw_axis_labels <- function(indexes) {

  lapply(1:length(indexes), function(offset) {
    df = indexes[[offset]]
    grid::textGrob(
      label=df$label,
      x=df$x,
      y=grid::unit((offset-1)*.pt,"mm"),
      gp = gpar(fontsize = 8, col = 'black')
    )
  })
}

#' @rdname ggplot2-ggproto
#' @format NULL
#' @usage NULL
#' @export
CoordConservation <- ggproto("CoordConservation", CoordCartesian,

  is_linear = function() TRUE,
  is_free = function() TRUE,
  render_axis_h = function(panel_params, theme) {
    kidlist = gList(panel_guides_grob(panel_params$guides, position = "bottom", theme = theme))

    if (panel_params$alignment_axis) {
      new_axis = draw_axis_labels(get_aa_indexes_from_scale(panel_params$x))
      i = 1
      while(i <= length(new_axis)) {
        kidlist[[ length(kidlist) + 1 ]] = new_axis[[i]] 
        i <- i+1     
      }
    }
    top_grob = zeroGrob()
    if (panel_params$conservation_axis) {
      top_grob <- draw_conservation_grobs(get_conservation_from_scale(panel_params$x))
    }
    viewport = grid::viewport(
      height=grid::unit(3 * .pt,"mm"),
      just=c("centre","bottom")
    )
    list(
      top = top_grob,
      bottom = gTree(
        children=kidlist, vp=viewport
      )
    )
  },

  setup_panel_params = function(self,scale_x,scale_y,params=list()) {
    if ('conservation' %in% names(params)) {
      attributes(scale_x)$conservation <- params$conservation
    }
    if ('aligned_indexes' %in% names(params)) {
      attributes(scale_x)$aligned_indexes <- params$aligned_indexes      
    }
    parent <- ggproto_parent(CoordCartesian, self)
    panel_params <- parent$setup_panel_params(scale_x, scale_y, params)
    panel_params$conservation_axis = self$conservation_axis
    panel_params$alignment_axis = self$alignment_axis
    panel_params
  },
  
  setup_params = function(data) {
    alignment_data = data[[1]]
    rescaled_idxs = lapply( unique(alignment_data$seq.id), function(seqid) {
      max_idx = max(alignment_data[alignment_data$seq.id == seqid, 'end'])
      min_idx = max(alignment_data[alignment_data$seq.id == seqid, 'start'])
      sapply( min_idx:max_idx, function(site) {
        rescale_site( alignment_data[alignment_data$seq.id == seqid, 'aa'], site )
      })
    })
    list(conservation=get_conservation(alignment_data),aligned_indexes=rescaled_idxs)
  }

)

"%||%" <- function(a, b) {
  if (!is.null(a)) a else b
}

"%|W|%" <- function(a, b) {
  if (!is.waive(a)) a else b
}

panel_guides_grob <- function(guides, position, theme) {
  guide <- guide_for_position(guides, position) %||% guide_none()
  guide_gengrob(guide, theme)
}

guide_for_position <- function(guides, position) {
  has_position <- vapply(
    guides,
    function(guide) identical(guide$position, position),
    logical(1)
  )

  guides <- guides[has_position]
  guides_order <- vapply(guides, function(guide) as.numeric(guide$order)[1], numeric(1))
  Reduce(guide_merge, guides[order(guides_order)])
}