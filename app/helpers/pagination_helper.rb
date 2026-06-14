module PaginationHelper
  def pagination_page_series(pagination)
    total_pages = pagination[:total_pages].to_i
    current_page = pagination[:current_page].to_i
    return [ 1 ] if total_pages <= 1

    return [ 1, 2 ] if total_pages == 2

    window_start = if current_page <= 2
      2
    elsif current_page >= total_pages - 1
      [ total_pages - 2, 2 ].max
    else
      current_page
    end
    window_end = [ window_start + 1, total_pages - 1 ].min

    [ 1, *window_start.upto(window_end) ].uniq
  end
end
