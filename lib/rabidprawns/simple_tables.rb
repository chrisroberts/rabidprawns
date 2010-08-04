unless([].respond_to?(:sum))
  class Array
    def sum
      self.inject(:+)
    end
  end
end

module Prawn
class Document
  # tables:: Array of tables
  # options:: Table options
  # 
  # Prints tables to document.
  # 
  # tables array: Each element within this array is a single table, allowing multiple tables to be
  # printed at once. The format of each element in the array is as follows:
  # 
  #   {:title => "I'm the title of the table",
  #    :contents => [{:headings => ['col1 heading', 'col2 heading', 'col3 heading'],
  #                  :rows => [['col1 value', 'col2 value', 'col3 value'],
  #                            ['col1 value2', 'col2 value2, {:content => 'col3 value3', :color => [100,0,0,0]}]]
  #                  :options => {:headings_text_color_default => [0,100,0,0]}
  #                 }]
  #    :options => {:title_padding => 20}
  #   }
  #
  # table hash explained:
  #   :title -> String - Title of the table
  #   :options -> Options applied to this table only
  #   :contents -> Array of Hashes of table contents. (this allows for dynamic resizing within a table to change the number
  #     of columns and headings without starting a new table)
  #     Table Hash:
  #       :headings -> Array of headings
  #       :rows -> Array of Arrays. Each array is a row
  #       :options -> Options applied to this set of contents only
  # 
  # Heading and row values can be a string value, a Hash or nil. If the value is nil, it will be blackedout using
  # the appropriate option for blacking out the cell. If it is a Hash, the :content key must be provided with the
  # string value for the cell. Supported format for value Hashes:
  # 
  #   {:content => 'cell content', :color => [0,0,0,100], :background_color => [0,100,0,0], :font => ['Times', {:style => 'bold', :size => 10}]}
  # 
  # Any or all of these values can by provided, with the exception of :content which MUST be provided. Any extra
  # key/value pairs are ignored.
  # 
  # Available options:
  # 
  #   :table_margin -> margin around entire all tables (the margin references the space around all tables. spacing between individual tables is set using :spacing)
  #   :table_margin_left -> left margin for all tables
  #   :table_margin_right -> right margin for all tables
  #   :table_margin_top -> top margin for all tables
  #   :table_margin_bottom -> bottom margin for all tables
  #   :default_font -> default font (defaults to first found font at size 6)
  #   :default_fill_color -> default fill color (defaults to black)
  #   :title_font -> font used for table title (defaults to first found font at size 18)
  #   :title_text_color -> text color for table title (defaults to white)
  #   :title_background_color -> background color for table title (defaults to blue)
  #   :title_text_alignment -> text alignment of title text (defaults :center)
  #   :title_padding -> extra padding around title text
  #   :headings_font -> default font used for cells in heading (defaults to first found font at font size 6)
  #   :headings_text_color_default -> default text color for cells in heading (defaults to black)
  #   :headings_text_colors -> text colors for cells in heading. zero based index corresponds to zero based column
  #   :headings_background_color_default -> default background color for heading cells (defaults to none)
  #   :headings_background_colors -> background colors for cells in heading. zero based index corresponds to zero based column
  #   :headings_blackout_color -> color to fill field when value does not exist (default to dark gray)
  #   :headings_text_alignment -> default text alignment for headings (defaults to center)
  #   :row_font -> default font used for cells in a row (defaults to first found font at font size 6)
  #   :row_text_color_default -> default text color for cells in a row (defaults to black)
  #   :row_text_colors -> text colors for cells in a row. zero based index corresponds to zero based column
  #   :row_background_color_default -> default background color for table cells (defaults to none)
  #   :row_background_colors -> background colors for cells in a row. zero based index corresponds to zero based column
  #   :row_text_alignment -> default text alignment for rows (defaults to center)
  #   :row_blackout_color -> color to fill field when value does not exist (defaults to dark gray)
  #   :border_color -> color of table border (defaults to black)
  #   :border_width -> width of table border
  #   :page_break_on_new_table -> move to a new page when a new table is started
  #   :show_title_after_page_break -> print table title after page break before continuing with table
  #   :show_headings_after_page_break -> print column headings after page break before continuing with data rows
  #   :new_page -> lambda called to start a new page
  #   :finalize_page -> lambda called before moving to the next page (example usage would be writing header/footer)
  #   :padding -> cell padding
  #   :spacing -> space between tables
  #   :y_initial -> initial y position when starting to write tables
  #   :page_width -> width of the page
  #   :page_height -> height of the page
  #   :break_for_min_width_on -> Array of single characters to break long strings on for wrapping
  #   :column_width_restrictions => {:fitted => [], :minimum => {}, :maximum => {}} # width restrictions (see extended explanation below)
  #   
  # Width restrictions can be applied to columns to allow some control over column sizing. All
  # restrictions work using a zero based index reference corresponding to table columns. For example:
  #   :fitted => [true, false, true]
  # will make the first and third columns of the table fitted. Fitted columns will be as wide as the widest element and will not
  # be expanded or shrunk when resizing. Minimum and maximum values can be set on columns as well:
  #   :minimum => {1 => 20, 4 => 40}, :maximum => {3 => 50}
  # where the key is the column index and the value is the minimum/maximum number of points the column is allowed.
  def simple_tables(tables, options={})
    opts = st_defaults.merge(options)
    new_page = opts[:new_page]
    finalize_page = opts[:finalize_page]
    opts.delete(:new_page)
    opts.delete(:finalize_page)
    break_page = lambda do
      finalize_page.call
      new_page.call
      [opts[:xstart], opts[:ystart]]
    end
    started_opts = Marshal.load(Marshal.dump(opts)) # deep copy
    new_opts_set = lambda{ Marshal.load(Marshal.dump(started_opts)) } # provide a copy when required
    st_expand_options(opts)
    tables = [tables] unless tables.is_a?(Array)
    xpos = opts[:xstart]
    ypos = opts[:y_initial] || opts[:ystart]
    tables.each do |table|
      opts = table[:options] ? new_opts_set.call.merge(table[:option]) : new_opts_set.call
      st_expand_options(opts, table[:options] ? :nomargins : nil)
      clean_table(table)
      title = table[:title]
      table[:contents] = [table[:contents]] unless table[:contents].is_a?(Array)
      widths = st_find_column_widths(table[:contents].first, opts)
      if((ypos - st_height_title(title, opts) - st_height_row(table[:contents].first[:headings], widths, opts, :headings) - st_height_row(table[:contents].first[:rows].first, widths, opts)) < opts[:yend])
        xpos,ypos = break_page.call
      end
      xpos, ypos = st_write_title(title, [xpos,ypos], opts)
      table[:contents].each do |row_collection|
        if(row_collection[:options])
          opts = opts.merge(row_collection[:options])
          st_expand_options(opts, :nomargins)
        end
        widths = st_find_column_widths(row_collection, opts)
        if((ypos - st_height_row(row_collection[:headings], widths, opts, :headings) - st_height_row(row_collection[:rows].first, widths, opts)) < opts[:yend])
          xpos,ypos = break_page.call
          xpos, ypos = st_write_title(title, [xpos,ypos], opts) if opts[:show_title_after_page_break]
        end
        xpos, ypos = st_write_row(row_collection[:headings], [xpos,ypos], widths, opts, :headings)
        row_collection[:rows].each do |row|
          if(ypos - st_height_row(row, widths, opts) < opts[:yend])
            xpos,ypos = break_page.call
            xpos,ypos = st_write_title(title, [xpos,ypos], opts) if opts[:show_title_after_page_break]
            xpos,ypos = st_write_row(row_collection[:headings], [xpos,ypos], widths, opts, :headings) if opts[:show_headings_after_page_break]
          end
          xpos, ypos = st_write_row(row, [xpos,ypos], widths, opts)
        end
      end
      ypos -= opts[:spacing]
    end
    finalize_page.call
    [xpos,ypos]
  end
  
  # table:: Hash of table contents
  # Cleans up the table contents filling in missing parts like heading or row information.
  # Will also check for column consistency within the rows.
  def clean_table(table)
    table[:contents] = [table[:contents]] unless table[:contents].is_a?(Array)
    table[:contents].push [] if table[:contents].empty?
    table[:contents].size.times do |idx|
      table[:contents][idx] = {} unless table[:contents][idx].is_a?(Hash)
      table[:contents][idx][:headings] = [] unless table[:contents][idx][:headings]
      table[:contents][idx][:rows] = [[]] unless table[:contents][idx][:rows]
      col_width = table[:contents][idx][:headings].size
      table[:contents][idx][:rows].each do |row|
        raise 'Improper number of columns used in row' if row.size != col_width && col_width > 0
        col_width = row.size
      end
    end
  end
  
  # Set the default values for building the table. All of these can be overridden when
  # calling #simple_tables
  def st_defaults
    default_margin = @default_margin || 0
    default_font = @default_font || [font_families.keys.first, {:style => font_families.values.first.keys.first, :size => 6}]
    {
      :table_margin => default_margin, # margin around entire all tables (the margin references the space around all tables. spacing between individual tables is set using :spacing)
      :table_margin_left => 0, # left margin for all tables
      :table_margin_right => 0, # right margin for all tables
      :table_margin_top => 0, # top margin for all tables
      :table_margin_bottom => 0, # bottom margin for all tables
      :default_font => default_font, # default font (defaults to first found font at size 6)
      :default_fill_color => [0,0,0,100], # default fill color (defaults to black)
      :title_font => [font_families.keys.first, {:style => font_families.values.first.keys.first, :size => 18}], # font used for table title (defaults to first found font at size 18)
      :title_text_color => [0,0,0,0], # text color for table title (defaults to white)
      :title_background_color => [100,100,0,0], # background color for table title (defaults to blue)
      :title_text_alignment => :center, # text alignment of title text
      :title_padding => 0, # extra padding around title text
      :headings_font => default_font, # default font used for cells in heading (defaults to first found font at font size 6)
      :headings_text_color_default => [0,0,0,100], # default text color for cells in heading (defaults to black)
      :headings_text_colors => [], # text colors for cells in heading. zero based index corresponds to zero based column
      :headings_background_color_default => nil, #default background color for heading cells (defaults to none)
      :headings_background_colors => [], # background colors for cells in heading. zero based index corresponds to zero based column
      :headings_blackout_color => [0,0,0,70], # color to fill field when value does not exist (default to dark gray)
      :headings_text_alignment => :center, # default text alignment for headings (defaults to center)
      :row_font => default_font, # default font used for cells in a row (defaults to first found found at font size 6)
      :row_text_color_default => [0,0,0,100], # default text color for cells in a row (defaults to black)
      :row_text_colors => [], # text colors for cells in a row. zero based index corresponds to zero based column
      :row_background_color_default => nil, # default background color for table cells (defaults to none)
      :row_background_colors => [], # background colors for cells in a row. zero based index corresponds to zero based column
      :row_text_alignment => :center, # default text alignment for rows (defaults to center)
      :row_blackout_color => [0,0,0,70], # color to fill field when value does not exist (defaults to dark gray)
      :border_color => [0,0,0,100], # color of table border (defaults to black)
      :border_width => 1, # width of table border
      :page_break_on_new_table => true, # move to a new page when a new table is started
      :show_title_after_page_break => true, # print table title after page break before continuing with table
      :show_headings_after_page_break => true, # print column headings after page break before continuing with data rows
      :column_width_restrictions => {:fitted => [], :minimum => {}, :maximum => {}}, # width restrictions (see extended explanation below)
      # Width restrictions can be applied to columns to allow some control over column sizing. All
      # restrictions work using a zero based index reference corresponding to table columns. For example:
      #   :fitted => [true, false, true]
      # will make the first and third columns of the table fitted. Fitted columns will be as wide as the widest element and will not
      # be expanded or shrunk when resizing. Minimum and maximum values can be set on columns as well:
      #   :minimum => {1 => 20, 4 => 40}, :maximum => {3 => 50}
      # where the key is the column index and the value is the minimum/maximum number of points the column is allowed.
      :new_page => lambda{ start_new_page }, # called to start a new page
      :finalize_page => lambda{}, # called before moving to the next page (example usage would be writing header/footer)
      :padding => 0, # cell padding
      :spacing => 0, # space between tables
      :y_initial => nil, # initial y position when starting to write tables
      :page_width => bounds.width, # width of the page
      :page_height => bounds.height, # height of the page
      :break_for_min_width_on => [',','/',' '] # must be single characters
      }
  end
  
  # opts:: Hash of current options
  # Fills out the options hash based on current options
  def st_expand_options(opts, *args)
    unless(args.include?(:nomargins))
      [:table_margin_left, :table_margin_right, :table_margin_top, :table_margin_bottom].each do |sym|
        opts[sym] += opts[:table_margin]
      end
      opts[:table_width] = opts[:page_width] - opts[:table_margin_left] - opts[:table_margin_right]
      opts[:ystart] = opts[:page_height] - opts[:table_margin_top] unless opts[:ystart]
      opts[:xstart] = opts[:table_margin_left] unless opts[:xstart]
      opts[:yend] = opts[:table_margin_bottom] unless opts[:yend]
      opts[:xstop] = opts[:page_width] - opts[:table_margin_right]
    end
    opts[:column_width_restrictions][:fitted] = [] unless opts[:column_width_restrictions][:fitted]
    opts[:column_width_restrictions][:minimum] = {} unless opts[:column_width_restrictions][:minimum]
    opts[:column_width_restrictions][:maximum] = {} unless opts[:column_width_restrictions][:maximum]
  end
  
  # args:: Arguments returned for this method
  # When called with no arguments, it returns current settings for
  # things modified when building the table. When arguments are
  # provided, it sets them. For example:
  # 
  #   original_settings = st_settings_helper
  #    # do some stuff here
  #   st_settings_helper(*original_settings)
  def st_settings_helper(*args)
    if(args.empty?)
      orig_fill = fill_color
      orig_stroke_color = stroke_color
      orig_width = line_width
      [orig_fill, orig_stroke_color, orig_width]
    else
      fill_color args[0]
      stroke_color args[1]
      line_width args[2]
      args
    end
  end
  
  # row:: Row of data
  # point:: x,y coordinate to start at
  # opts:: Hash of options provided for building the table
  # type:: Defaults to row. If not :row, assumes a heading is being written
  # Writes a table row to the page
  # Returns:: new x,y coordinate
  def st_write_row(row, point, widths, opts, type=:row)
    if(type != :row && row.empty?)
      return point
    end
    xpos,ypos = point
    startx = xpos
    origs = st_settings_helper
    height = st_height_row(row, widths, opts, type)
    pad = opts[:padding]
    row.each_with_index do |item,idx|
      bounding_box [xpos,ypos], :height => height, :width => widths[idx] do
        if(item.nil?)
          fill_color opts["#{type}_blackout_color".to_sym]
          fill_rectangle [0, bounds.height], bounds.width, bounds.height
        else(item.is_a?(Hash))
          item = {:content => item.to_s} unless item.is_a?(Hash)
          background = item[:background_color] || opts["#{type}_background_colors".to_sym][idx] || opts["#{type}_background_color_default".to_sym]
          if(background)
            cur_fill = fill_color
            fill_color background
            fill_rectangle [0, bounds.height], bounds.width, bounds.height
            fill_color cur_fill
          end
          cur_fill = fill_color
          fill_color item[:color] || opts["#{type}_text_colors".to_sym][idx] || opts["#{type}_text_color_default".to_sym]
          font *(item[:font] || opts["#{type}_font".to_sym]) do
            alignment = item[:align] || opts["#{type}_text_alignment".to_sym]
            boxed_width = bounds.width - (2 * pad)
            boxed_height = bounds.height - (2 * pad)
            text_height = height_of(item[:content], boxed_width)
            valign_movement = text_height < boxed_height ? (boxed_height - text_height) / 2.0  : 0
            bounding_box [pad, bounds.height - pad], :height => boxed_height, :width => boxed_width do
              move_down valign_movement
              text item[:content], :align => alignment
            end
          end
          fill_color cur_fill
        end
        line_width opts[:border_width]
        stroke_color opts[:border_color]
        stroke_bounds
      end
      xpos += widths[idx]
    end
    st_settings_helper *origs
    [startx,ypos - height]
  end
  
  # title:: String title for table
  # point:: x,y coordinate to start printing
  # opts:: Hash of options for table building
  # Prints the table title
  # Returns:: new x,y coordinate
  def st_write_title(title, point, opts)
    unless(title)
      return point
    end
    xpos,ypos = point
    origs = st_settings_helper
    height = st_height_title(title, opts)
    font *opts[:title_font] do
      pad = opts[:title_padding] + opts[:padding]
      bounding_box point, :width => opts[:table_width], :height => height do
        fill_color opts[:title_background_color]
        fill_rectangle [0, bounds.height], bounds.width, bounds.height
        fill_color opts[:title_text_color]
        boxed_width = bounds.width - (2 * pad)
        boxed_height = bounds.height - (2 * pad)
        text_height = height_of(title, boxed_width)
        valign_movement = text_height < boxed_height ? (boxed_height - text_height) / 2.0  : 0
        bounding_box [pad, bounds.height - pad], :height => boxed_height, :width => boxed_width do
          move_down valign_movement
          text title, :align => opts[:title_text_alignment]
        end
        line_width opts[:border_width]
        stroke_color opts[:border_color]
        stroke_bounds
      end
    end
    st_settings_helper(*origs)
    [xpos, ypos - height]
  end
  
  # table:: Hash of table contents
  # opts:: Hash of options for building table
  # Determine column widths for the table
  def st_find_column_widths(table, opts)
    info = {:widths => [], :min_widths => []}
    ([table[:headings]] + table[:rows]).each_with_index do |row, i|
      type = i == 0 ? 'headings' : 'row'
      row.each_with_index do |item, idx|
        item = {:content => item.to_s} unless item.is_a?(Hash)
        font *(item[:font] || opts["#{type}_font".to_sym]) do
          string = item[:content].to_s
          w = width_of(string) + (opts[:padding] * 2)
          info[:widths][idx] = w if info[:widths][idx].nil? || info[:widths][idx] < w
          biggest_word = string.tr(opts[:break_for_min_width_on].join(''), opts[:break_for_min_width_on].first).strip.split(opts[:break_for_min_width_on].first).max{|a,b|a.length <=> b.length}
          m = (biggest_word ? width_of(biggest_word) : 0) + (opts[:padding] * 2)
          info[:min_widths][idx] = m if info[:min_widths][idx].nil? || info[:min_widths][idx] < m
        end
      end
    end
    opts[:column_width_restrictions][:minimum].each_pair do |idx, val|
      info[:widths][idx] = val if info[:widths][idx] < val && info[:min_widths][idx] < val
    end
    if(info[:widths].sum > opts[:table_width])
      info = st_shrink_widths(info, opts)
    elsif(info[:widths].sum < opts[:table_width] && info[:widths].sum > 0)
      info = st_expand_widths(info, opts)
    end
    info[:widths]
  end
  
  # info:: Hash of width and minimum width values for table columns
  # opts:: Hash of options for building the table
  # Shrinks column widths until table fits within bounds. Will raise error
  # if unable to fit table within bounds.
  def st_shrink_widths(info, opts)
    current_width = info[:widths].sum
    reduce_by = current_width - opts[:table_width]
    no_change = false
    while(reduce_by > 0 && !no_change)
      no_change = true
      modable = {}
      info[:widths].each_with_index do |w, idx|
        modable[idx] = w if !opts[:column_width_restrictions][:fitted][idx] && w != opts[:column_width_restrictions][:minimum][idx]
      end
      modable.each_pair do |idx, w|
        removal = reduce_by * (w / modable.values.sum)
        unless(w <= info[:min_widths][idx])
          hard_min = [opts[:column_width_restrictions][:minimum][idx].to_f, info[:min_widths][idx]].max
          if(hard_min > w - removal && w > hard_min)
            no_change = false
            info[:widths][idx] = hard_min
          elsif(hard_min < w - removal)
            no_change = false
            info[:widths][idx] = w - removal
          end
        end
      end
      current_width = info[:widths].sum
      reduce_by = current_width - opts[:table_width]
    end
    if(no_change && reduce_by > 0)
      raise "Failed to fit table data within boundaries. Too wide by: #{reduce_by} units"
    else
      info
    end
  end
  
  # info:: Hash of width and minimum width values for table columns
  # opts:: Hash of options for building the table
  # Expands column widths until table fills bounds. Will raise error if
  # unable to expand columns enough to fit bounds (due to column size restrictions)
  # TODO: add check for fitted columns. check for no change like we do when shrinking
  def st_expand_widths(info, opts)
    expand_by = opts[:table_width] - info[:widths].sum
    while(expand_by > 0)
      modable = {}
      info[:widths].each_with_index do |w, idx|
        modable[idx] = w if !opts[:column_width_restrictions][:fitted][idx] && w != opts[:column_width_restrictions][:maximum][idx]
      end
      extra_pad = expand_by / modable.size.to_f
      modable.each_pair do |idx, w|
        if(opts[:column_width_restrictions][:maximum][idx] && opts[:column_width_restrictions][:maximum][idx] < w + extra_pad)
          info[:widths][idx] = opts[:column_width_restrictions][:maximum][idx]
        else
          info[:widths][idx] = w + extra_pad
        end
      end
      expand_by = opts[:table_width] - info[:widths].sum
    end
    info
  end
  
  # title:: String
  # opts:: Hash of options for building the table
  # Returns the height of the title
  def st_height_title(title, opts)
    h = 0
    font *opts[:title_font] do
      h = height_of(title.to_s, opts[:table_width]) + (opts[:padding] * 2) + (opts[:title_padding] * 2)
    end
    h + 2 # bit of safety to keep from busting the cell
  end
  
  # row:: Array of row values
  # widths:: Array of column width values
  # opts:: Hash of options for building the table
  # type:: row or heading
  # Returns the max height for the given row
  def st_height_row(row, widths, opts, type=:row)
    return 0 if row.nil? || row.empty?
    h = 0
    row.each_with_index do |item, idx|
      test_height = 0
      item = {:content => item.to_s} unless item.is_a?(Hash)
      font *(item[:font] || opts["#{type}_font".to_sym]) do
        test_height = height_of(item[:content].to_s, widths[idx] - (opts[:padding] * 2))
      end
      h = test_height if h < test_height
    end
    h + (opts[:padding] * 2) + 2 # bit of safety to keep from busting the cell
  end
end
end