module Prawn
class Document
  # text:: Text to print
  # title:: Title of page
  # options:: Options hash
  # Print a columned page
  # Available options:
  #   :columns -> number of columns on page
  #   :title_colspan -> number of columns title should span
  #   :column_pad -> padding between columns
  #   :title_font -> Array of font information
  #   :default_font -> Array of font information
  #   :new_page -> lambda to be called to start a new page
  #   :finalize_page -> lambda to be called when a page has been completed
  #   :page_height -> height of the page
  #   :page_width -> width of the page
  #   :margin -> margin on all sides
  #   NOTE: Below margin options will have :margin added to them
  #   :margin_top -> margin on top
  #   :margin_bottom -> margin on bottom
  #   :margin_left -> margin on left
  #   :margin_right -> margin on right
  #   :title_to_text_pad -> padding between title and start of text
  #   :new_page_at_start -> move to new page before starting
  def columned_page(text, title, options = {})
    opts = {:columns => 2, :title_colspan => 1, :column_pad => 10,
            :title_font => [font_families.keys.first, {:style => font_families.values.first.keys.first, :size => 18}],
            :default_font => [font_families.keys.first, {:style => font_families.values.first.keys.first, :size => 6}],
            :new_page => lambda{ start_new_page }, :finalize_page => lambda{},
            :page_height => bounds.height, :page_width => bounds.width, :margin => 0,
            :margin_top => 0, :margin_bottom => 0, :margin_left => 0, :margin_right => 0,
            :title_to_text_pad => 5, :new_page_at_start => false
           }.merge(options)
    [:columns, :title_colspan, :column_pad, :page_height, :page_width,
     :margin, :margin_top, :margin_bottom, :margin_left, :margin_right].each{|x| opts[x] = opts[x].to_i}
    opts[:title_colspan] = opts[:columns] if opts[:title_colspan] > opts[:columns]
    [:margin_top, :margin_bottom, :margin_left, :margin_right].each{|x|opts[x] += opts[:margin]} if opts[:margin] > 0
    if(opts[:new_page_at_start])
      opts[:new_page].call
    else
      opts[:new_page_at_start] = true
    end
    ypos = opts[:page_height] - opts[:margin_top]
    columns = []
    total_width = opts[:page_width] - (opts[:column_pad] * opts[:columns]) - opts[:margin_left] - opts[:margin_right]
    column_width = total_width.to_f / opts[:columns]
    title_height = 0
    font(*opts[:title_font]) do
      title_width = (column_width * opts[:title_colspan]) + (opts[:column_pad] * (opts[:title_colspan] - 1))
      title_height = height_of(title, title_width)
      bounding_box([opts[:margin_left], ypos], :width => title_width, :height => title_height) do
        text title
      end
    end
    font(*opts[:default_font]) do
      ypos -= title_height + opts[:title_to_text_pad] # pad
      below_title = ypos
      opts[:columns].times do |i|
        if(i < opts[:title_colspan])
          ypos = below_title
        else
          ypos = opts[:page_height] - opts[:margin_top]
        end
        xpos = opts[:margin_left] + (column_width * i) + (opts[:column_pad] * i)
        bounding_box([xpos, ypos], :width => column_width, :height => opts[:page_height] - (opts[:page_height] - ypos) - opts[:margin_bottom]) do
          text = text_box text, :height => bounds.height, :width => bounds.width
        end
      end
    end
    opts[:finalize_page].call
    columned_page(text, title, options) unless text.empty?
  end
end
end