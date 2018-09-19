#!/usr/bin/env ruby

require "logger"
require_relative "util.rb"

def check_links(file)
  logger = Logger.new(STDERR, level: :info)
  doc = Nokogiri::HTML(open(file))
  a_elements = doc.css("a")
  a_elements.each do |a_elem|
    href = a_elem["href"]
    href = href.sub(/#.*\z/, "")
    next if href =~ /\Ahttps?:\/\//
    next if href =~ /\Ajavascript:/
    href = Pathname(File.dirname(file)) + href
    href = href.sub(/\A\//, File.dirname($0) + "/")
    next if File.exist? href
    next if File.exist? "#{href}.html"
    logger.warn("#{href}: link not found in #{file}")
  end
end

if $0 == __FILE__
  files = ARGV
  files.each do |file|
    check_links(file)
  end
end
