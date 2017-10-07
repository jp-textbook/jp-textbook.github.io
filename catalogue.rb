#!/usr/bin/env ruby

require "fileutils"

require_relative "util.rb"

data = load_turtle("catalogue.ttl")
sitemap = Sitemap.new
template = PageTemplate.new("template/catalogue.html.erb")

data.each do |uri, v|
  param = {
    uri: uri,
    style: "../../style.css",
    name: v["http://schema.org/name"][:ja],
    datePublished: v["http://schema.org/datePublished"].first,
    usageYear: v["https://w3id.org/jp-textbook/usageYear"].first,
    school: v["https://w3id.org/jp-textbook/school"].first,
    url: v["http://schema.org/url"],
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"],
    callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"].first,
    recordID: v["http://dl.nier.go.jp/library/vocab/recordID"].first,
    itemID: v["http://dl.nier.go.jp/library/vocab/itemID"].first,
  }
  file = uri.sub("https://w3id.org/jp-textbook/", "") + ".html"
  p file
  dir = File.dirname(file)
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(file, "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << file
end

open("sitemaps-catalogue.xml", "w"){|io| io.print sitemap.to_xml }
