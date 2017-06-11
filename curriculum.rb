#!/usr/bin/env ruby

require "fileutils"
require_relative "util.rb"

data = load_turtle("curriculum.ttl")
sitemap = Sitemap.new
template = PageTemplate.new("template/curriculum.html.erb")

data.each do |uri, v|
  #q = SPARQL.parse("SELECT * WHERE {
  #                   ?s <https://w3id.org/jp-textbook/curriculum> <#{uri}>.
  #                   ?s <https://w3id.org/jp-textbook/school> <http://ja.dbpedia.org/resource/小学校>.
  #                 }")
  #textbook.query(q) do |result|
  #  p result
  #end
  param = {
    uri: uri,
    name: v["http://schema.org/name"].first,
    datePublished: v["http://schema.org/datePublished"].first,
    startDate: v["http://schema.org/startDate"].first,
    startDate_str: Date.parse(v["http://schema.org/startDate"].first).strftime("%Y年%m月"),
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].first,
  }
  file = uri.sub("https://w3id.org/jp-textbook/", "") + ".html"
  dir = File.dirname(file)
  p file
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(file, "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << file
end

open("sitemaps-curriculum.xml", "w"){|io| io.print sitemap.to_xml }
