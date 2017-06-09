#!/usr/bin/env ruby

require_relative "util.rb"

prefix = []
ttl = []

ARGV.each do |file|
  load_turtle(file)
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

puts prefix.uniq
puts ttl
