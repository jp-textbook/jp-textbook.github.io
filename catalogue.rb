#!/usr/bin/env ruby

require "fileutils"
require "era_ja"

require_relative "util.rb"

include Textbook
data = load_turtle("catalogue.ttl")
school_data = load_turtle("school.ttl")
sitemap = Sitemap.new
template = PageTemplate.new("template/catalogue.html.erb")
template_en = PageTemplate.new("template/catalogue.html.en.erb")

data.each do |uri, v|
  school =  v["https://w3id.org/jp-textbook/school"].first
  param = {
    uri: uri,
    file: uri.sub("https://w3id.org/jp-textbook/", "") + ".html",
    file_en: uri.sub("https://w3id.org/jp-textbook/", "en/") + ".html",
    style: "../../style.css",
    name: v["http://schema.org/name"][:ja],
    name_en: v["http://schema.org/name"][:en],
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    datePublished: v["http://schema.org/datePublished"].first,
    usageYear: v["https://w3id.org/jp-textbook/usageYear"].first,
    school_name: school_data[school]["http://schema.org/name"][:ja],
    school_name_en: school_data[school]["http://schema.org/name"][:en],
    url: v["http://schema.org/url"],
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"],
    callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"].first,
    recordID: v["http://dl.nier.go.jp/library/vocab/recordID"].first,
    itemID: v["http://dl.nier.go.jp/library/vocab/itemID"].first,
  }
  p param[:file]
  dir = File.dirname(param[:file])
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(param[:file], "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << param[:file]
  param[:style] = File.join("..", param[:style])
  dir = File.dirname(param[:file_en])
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(param[:file_en], "w") do |io|
    io.print template_en.to_html(param, :en)
  end
  sitemap << param[:file_en]
end

open("sitemaps-catalogue.xml", "w"){|io| io.print sitemap.to_xml }
