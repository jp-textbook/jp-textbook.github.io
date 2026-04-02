#!/usr/bin/env ruby

require "net/http"
require "uri"
require "json"
require "roo"
require "pp"

require "ttl2html"
require_relative "util.rb"

class App < TTL2HTML::App
  include TTL2HTML
  def initialize
    super
    file = find_turtle("../jp-cos.github.io/all")
    load_turtle(file)
  end
  def expand_coscode_hierarchy(coscodes)
    results = []
    return [] if coscodes.nil? or coscodes.empty?
    coscodes.strip.split(/,/).each do |coscode|
      next if coscode.nil? or coscode.empty?
      results << coscode
      d = @data["https://w3id.org/jp-cos/#{coscode}"]
      if d.nil?
        STDERR.puts "WARN: not found: #{coscode}"
        next
      end
      if d and d["http://schema.org/hasPart"]
        d["http://schema.org/hasPart"].each do |child|
          results << expand_coscode_hierarchy(child.to_s.split(/\//).last)
        end
      end
    end
    results = results.flatten.sort.uniq
  end
  def expand_coscode_hierarchy_upward(coscodes)
    results = []
    coscodes = coscodes.sort
    while not coscodes.empty?
      coscode = coscodes.pop
      parent = @data_inverse["https://w3id.org/jp-cos/#{coscode}"]
      if parent and parent["http://schema.org/hasPart"]
        parent["http://schema.org/hasPart"].each do |e|
          children = @data[e]["http://schema.org/hasPart"].map{|c| c.last_part }
          #p [:children, children]
          intersection = (coscodes + results + [coscode]).intersection(children)
          #p [:intersection, intersection]
          if intersection.size == children.size
            coscodes << e.last_part
          end
        end
      end
      results << coscode
    end
    results.sort.uniq
  end
end

#$0 = File.expand_path($0, __dir__)
if $0 == __FILE__
  if ARGV.size < 1
    puts "USAGE #$0 filename [sheetname]"
    exit
  end
  xlsx = Roo::Spreadsheet.open(ARGV[0])
  if ARGV[1]
    xlsx.default_sheet = ARGV[1]
  end
  skip = true
  cos_idx = nil
  app = App.new
  xlsx.each_row_streaming(pad_cels: true) do |row|
    if skip
      if row[0].to_s == "No" or row[0].to_s =~ /ID$/
        skip = false
        cos_idx = row.index{|e| e.to_s == "cosコード" or e.to_s == "オリジナルcos" or e.to_s =~ /cosコード/ }
        raise "cos_idx not found: one of the header must have either the values of \"cosコード\" or \"オリジナルcos\"" if cos_idx.nil?
      end
      next
    end
    next if row.empty? or row[0].empty?
    coscode = row.find{|e| e.coordinate[1] == cos_idx + 1 }.to_s
    if coscode and not coscode.empty?
      expanded = app.expand_coscode_hierarchy(coscode)
      expanded = app.expand_coscode_hierarchy_upward(expanded)
      puts [ row[0], coscode, expanded.join(",") ].join("\t")
    else
      puts row[0]
    end
  end
end
