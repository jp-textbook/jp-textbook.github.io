#!/usr/bin/env ruby

require_relative "util.rb"
include Textbook

data = {}
if ARGV.size > 0
  ARGV.each do |file|
    data.merge!(load_turtle(file, noexpand: true)) do |key, old, new|
      old + new
    end
  end
else
  data = load_turtle("all.ttl")
end
data.each do |uri, v|
  next if not uri =~ %r|\Ahttps://w3id.org/jp-textbook/|
  next if uri =~ %r|\A_:|
  p [uri,v] if not v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  #p v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  if v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].first == "https://w3id.org/jp-textbook/Textbook"
    nier_ids = []
    rc_ids = []
    v["https://w3id.org/jp-textbook/item"].each do |item|
      if data[item]["http://dl.nier.go.jp/library/vocab/recordID"]
        nier_ids << data[item]["http://dl.nier.go.jp/library/vocab/recordID"].first
      elsif data[item]["http://dl.nier.go.jp/library/vocab/textbook-rc/recordID"]
        rc_ids << data[item]["http://dl.nier.go.jp/library/vocab/textbook-rc/recordID"].first
      end
    end
    nier_ids.each do |record_id|
      puts [ record_id, "https://nieropac.nier.go.jp/ebopac/#{record_id}", uri, rc_ids.join(", ") ].join("\t")
    end
  end
end
