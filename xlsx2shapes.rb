#!/usr/bin/env ruby

require "roo"
require "logger"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  if ARGV.size < 1
    puts "USAGE: #$0 data.xlsx"
    exit
  end

  logger = Logger.new(STDERR, level: :info)

  puts <<EOF
@prefix schema: <http://schema.org/>.
@prefix textbook: <https://w3id.org/jp-textbook/>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
@prefix owl: <http://www.w3.org/2002/07/owl#>.
@prefix dct: <http://purl.org/dc/terms/>.
@prefix bf: <http://id.loc.gov/ontologies/bibframe/>.
@prefix sh: <http://www.w3.org/ns/shacl#>.
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>.
@prefix skos: <http://www.w3.org/2004/02/skos/core#>.
@prefix nier: <http://dl.nier.go.jp/library/vocab/>.
@prefix textbook-rc: <http://dl.nier.go.jp/library/vocab/textbook-rc/>.
@prefix qb: <http://purl.org/linked-data/cube#>.
EOF

  shapes = {}
  xlsx = Roo::Excelx.new(ARGV[0])
  xlsx.each_with_pagename do |name, sheet|
    headers = sheet.row(1)
    uri = headers.first
    shapes[uri] = ["<#{uri}> a sh:NodeShape"]
    order = 1
    sheet.each_with_index do |row, idx|
      row_h = map_xlsx_row_headers(row, headers)
      case row.first
      when "sh:targetClass"
        shapes[uri] << "#{format_property("sh:targetClass", row[1])}" if row[1]
      when "sh:property"
        prop_values = []
        headers[1..-1].each do |prop|
          next if row_h[prop].empty?
          case prop
          when /\@(\w+)\z/
            lang = $1
            property_name = prop.sub(/\@(\w+)\z/, "")
            prop_values << format_property(property_name, row_h[prop], lang)
          when "sh:minCount", "sh:maxCount"
            prop_values << format_property(prop, row_h[prop].to_i)
          when "sh:languageIn"
            prop_values << "  sh:languageIn (#{row_h[prop].split.map{|e| format_pvalue(e) }.join(" ")})"
          when "sh:uniqueLang"
            case row_h[prop]
            when "true"
              prop_values << "  sh:uniqueLang true"
            when "false"
              prop_values << "  sh:uniqueLang false"
            else
              logger.warn "sh:uniqueLang value unknown: #{row_h[prop]} at #{uri}"
            end
          else
            prop_values << format_property(prop, row_h[prop])
          end
        end
        prop_values << format_property("sh:order", order)
        order += 1
        str = prop_values.join(";\n  ")
        shapes[uri] << "  sh:property [\n  #{str}\n  ]"
      when "sh:or"
        shapes[uri] << "  sh:or (#{row[1..-1].select{|e| not e.empty? }.map{|e| format_pvalue(e) }.join(" ")})"
      end
    end
  end
  shapes.sort_by{|uri, val| uri }.each do |uri, val|
    puts
    puts shapes[uri].join(";\n")
    puts "."
  end
end
