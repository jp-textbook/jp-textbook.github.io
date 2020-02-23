#!/usr/bin/env ruby

require "nkf"

if ARGV.size != 2
  puts "USAGE: #$0 file1.ttl file2.ttl"
  exit
end

require_relative "util.rb"
include Textbook

data1 = load_turtle(ARGV[0], noexpand: true)
data2 = load_turtle(ARGV[1], noexpand: true)

data1.each do |k,v|
  if data2[k]
    v.keys.each do |property|
      next if property =~ /usageYear/
      next if v[property].first =~ /^_:/ or v[property].first =~ /^https?:\/\//
      v1 = v[property].map{|e| NKF.nkf("-ZWw1", e) }
      v2 = data2[k][property]
      v2 = data2[k][property].map{|e| NKF.nkf("-ZWw1", e) } if data2[k][property]
      if v1 != v2
        v["https://w3id.org/jp-textbook/item"].each do |item|
          puts [ data1[item]["http://dl.nier.go.jp/library/vocab/recordID"].first,
                 property,
                 v[property].inspect, data2[k][property].inspect].join("|")
        end
      end
    end
  end
end
