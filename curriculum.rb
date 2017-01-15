#!/usr/bin/env ruby

require "fileutils"
require "erb"
require "rdf/turtle"
require "linkeddata"

include ERB::Util

g = RDF::Graph.load("curriculum.ttl", format:  :ttl)
data = {}
g.each do |s, v, o|
  data[s] ||= {}
  data[s][v.to_s] = o.to_s
end
p data.keys.size

data.each do |uri, v|
  p uri
  p v
  param = {
    uri: uri,
    site_title: "教科書 Linked Open Data (LOD)",
    name: v["http://schema.org/name"],
    datePublished: v["http://schema.org/datePublished"],
    startDate: v["http://schema.org/startDate"],
    datePublished_str: Date.parse(v["http://schema.org/datePublished"]).strftime("%Y年%m月"),
    startDate_str: Date.parse(v["http://schema.org/startDate"]).strftime("%Y年%m月"),
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"],
  }
  p param
  template = open("template/curriculum.html.erb"){|io| io.read }
  file = uri.path.sub(/\A\/jp-textbook\//, "") + ".html"
  dir = File.dirname(file)
  p file
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(file, "w") do |io|
    io.print ERB.new(template).result(binding)
  end
end
