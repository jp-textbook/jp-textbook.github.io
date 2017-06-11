#!/usr/bin/env ruby

require "fileutils"
require_relative "util.rb"

data = load_turtle("curriculum.ttl")
area_data = load_turtle("subjectArea.ttl")
subject_data = load_turtle("subject.ttl")
sitemap = Sitemap.new
template = PageTemplate.new("template/curriculum.html.erb")

data.each do |uri, v|
  param = {
    uri: uri,
    style: "../../style.css",
    name: v["http://schema.org/name"].first,
    datePublished: v["http://schema.org/datePublished"].first,
    startDate: v["http://schema.org/startDate"].first,
    startDate_str: Date.parse(v["http://schema.org/startDate"].first).strftime("%Y年%m月"),
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].first,
    subjectArea: [],
  }
  area_data[uri]["https://w3id.org/jp-textbook/hasSubjectArea"].sort_by{|area|
    area_data[area]["http://purl.org/linked-data/cube#order"].first.to_i
  }.each do |area|
    subjects = []
    if subject_data[area] and subject_data[area]["https://w3id.org/jp-textbook/hasSubject"]
      subjects = subject_data[area]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|subject|
        subject_data[subject]["http://purl.org/linked-data/cube#order"].first.to_i
      }
    end
    param[:subjectArea] << { name: area.last_part, subjects: subjects }
  end
  #p param
  file = uri.sub("https://w3id.org/jp-textbook/", "") + ".html"
  p file
  dir = File.dirname(file)
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(file, "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << file
end

open("sitemaps-curriculum.xml", "w"){|io| io.print sitemap.to_xml }
