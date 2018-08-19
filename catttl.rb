#!/usr/bin/env ruby

require_relative "util.rb"
include Textbook

prefix = []
ttl = []

ARGV.each do |file|
  filename = find_turtle(file)
  File.readlines(filename).each do |line|
    line = line.chomp
    next if line.empty?
    if line =~ /^@prefix\s+/
      prefix << line.gsub(/\s+/, " ").strip
    else
      ttl << line
    end
  end
end
ARGV.each do |file|
  filename = find_turtle(file)
  STDERR.puts "<li><a href=\"#{filename}\">#{filename}</a></li>"
end

puts prefix.uniq
puts ttl
