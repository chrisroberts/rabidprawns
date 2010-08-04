require 'prawn'

class RabidPrawns
  class << self
    # Returns array of available rabids for loading
    def available_rabids
      libs = []
      Dir.new(File.expand_path(File.expand_path(__FILE__) + '/../rabidprawns')).each do |item|
        next if %w(. ..).include? item
        libs << item.gsub('.rb', '').to_sym
      end
      libs
    end
    
    # args:: rabid symbols
    # Load the given rabids
    def load_rabid(*args)
      list = self.available_rabids
      args.each do |arg|
        raise ArgumentError.new "Unknown rabid requested: #{arg}" unless list.include?(arg)
        require "rabidprawns/#{arg}"
      end
    end
    
    alias :load_rabids :load_rabid
  end
end

module Prawn
class Document
  def height_of(text, args)
    unless(args.is_a?(Hash))
      args = {:width => args}
    end
    super(text, args)
  end
end
end