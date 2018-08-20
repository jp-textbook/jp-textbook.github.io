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

module Textbook::Catalogue
  RELATED_LINKS = {
    /web.archive.org/ => :_waybackmachine,
    /warp.da.ndl.go.jp/ => :_warp,
    /ci.nii.ac.jp/ => :ncid,
    /id.ndl.go.jp/ => :jpno,
  }
end

data.each do |uri, v|
  school =  v["https://w3id.org/jp-textbook/school"].first
  param = {
    uri: uri,
    file: uri.sub("https://w3id.org/jp-textbook/", "") + ".html",
    file_en: uri.sub("https://w3id.org/jp-textbook/", "en/") + ".html",
    name: v["http://schema.org/name"][:ja],
    name_en: v["http://schema.org/name"][:en],
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    datePublished: v["http://schema.org/datePublished"].first,
    usageYear: v["https://w3id.org/jp-textbook/usageYear"].first,
    school: school,
    school_name: school_data[school]["http://schema.org/name"][:ja],
    school_name_en: school_data[school]["http://schema.org/name"][:en],
    url: v["http://schema.org/url"],
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].map{|url|
      key = Textbook::Catalogue::RELATED_LINKS.keys.find do |r|
        r.match(url)
      end
      { key: Textbook::Catalogue::RELATED_LINKS[key], url: url }
    }.sort_by{|h|
      h[:key]
    },
    callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"].first,
    recordID: v["http://dl.nier.go.jp/library/vocab/recordID"].first,
    itemID: v["http://dl.nier.go.jp/library/vocab/itemID"].first,
  }
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
end

open("sitemaps-catalogue.xml", "w"){|io| io.print sitemap.to_xml }
