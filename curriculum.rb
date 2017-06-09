#!/usr/bin/env ruby

require "fileutils"
require "erb"
require "rdf/turtle"
require "linkeddata"

require_relative "util.rb"

include ERB::Util

data = load_turtle("curriculum.ttl")
sitemap = Sitemap.new

#textbook = RDF::Repository.load("textbook.ttl")

data.each do |uri, v|
  p uri
  p v
  #q = SPARQL.parse("SELECT * WHERE {
  #                   ?s <https://w3id.org/jp-textbook/curriculum> <#{uri}>.
  #                   ?s <https://w3id.org/jp-textbook/school> <http://ja.dbpedia.org/resource/小学校>.
  #                 }")
  #textbook.query(q) do |result|
  #  p result
  #end
  param = {
    uri: uri,
    site_title: "教科書 Linked Open Data (LOD)",
    name: v["http://schema.org/name"].first,
    datePublished: v["http://schema.org/datePublished"].first,
    startDate: v["http://schema.org/startDate"].first,
    startDate_str: Date.parse(v["http://schema.org/startDate"].first).strftime("%Y年%m月"),
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].first,
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
  sitemap << file
end

open("sitemaps-curriculum.xml", "w"){|io| io.print sitemap.to_xml }
