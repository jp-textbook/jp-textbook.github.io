#!/usr/bin/env ruby

require "fileutils"
require_relative "util.rb"

include Textbook
data = load_turtle("schema.ttl")
sitemap = Sitemap.new
class_template = PageTemplate.new("template/class.html.erb")
class_template_en = PageTemplate.new("template/class.html.en.erb")
property_template = PageTemplate.new("template/property.html.erb")
property_template_en = PageTemplate.new("template/property.html.en.erb")

data.each do |uri, v|
  type = v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].first
  basename = uri.sub("https://w3id.org/jp-textbook/", "")
  basename += "/index" if File.directory?(basename)
  param = {
    uri: uri,
    file: basename + ".html",
    file_en: File.join("en", basename + ".html"),
    name: v["http://www.w3.org/2000/01/rdf-schema#label"][:ja],
    name_en: v["http://www.w3.org/2000/01/rdf-schema#label"][:en],
    label: v["http://www.w3.org/2000/01/rdf-schema#label"][:ja],
    label_en: v["http://www.w3.org/2000/01/rdf-schema#label"][:en],
    comment: v["http://www.w3.org/2000/01/rdf-schema#comment"][:ja],
    subClassOf: v["http://www.w3.org/2000/01/rdf-schema#subClassOf"],
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"],
    sameAs: v["http://www.w3.org/2002/07/owl#sameAs"] ? v["http://www.w3.org/2002/07/owl#sameAs"].first : nil,
    domain: v["http://www.w3.org/2000/01/rdf-schema#domain"],
    range: v["http://www.w3.org/2000/01/rdf-schema#range"],
  }
  case type
  when "http://www.w3.org/2000/01/rdf-schema#Class"
    template = class_template
    template_en = class_template_en
  when "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property"
    template = property_template
    template_en = property_template_en
  else
    raise "unknown type: #{type}"
  end
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
end

open("sitemaps-schema.xml", "w"){|io| io.print sitemap.to_xml }
