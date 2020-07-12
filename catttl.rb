#!/usr/bin/env ruby

require_relative "util.rb"
include Textbook

prefix = {}
ttl = []

ARGV.each do |file|
  filename = find_turtle(file)
  File.readlines(filename).each do |line|
    line = line.chomp
    next if line.empty?
    if line =~ /^@prefix\s+(\w[\w\-]*):\s*<(.+)>/
      prefix[$1] ||= []
      prefix[$1] << $2
    else
      ttl << line
    end
  end
end
ARGV.each do |file|
  filename = find_turtle(file)
  STDERR.puts filename
end

prefix.each do |k, v|
  STDERR.puts "Duplicate prefixes: #{k}: #{v}" if v.uniq.size > 1
  prefix[k] = v.sort.first
end
dups = prefix.values.group_by{|e| e }.select{|k, v| v.size > 1 }.keys
unless dups.empty?
  dups.each do |uri|
    uris = prefix.keys.select{|e| prefix[e] == uri }
    STDERR.puts "Duplicate prefixes: #{uri} (#{uris.join(",")})"
  end
end

prefix.sort.each do |prefix, uri|
  puts "@prefix #{prefix}: <#{uri}>."
end
puts ttl
