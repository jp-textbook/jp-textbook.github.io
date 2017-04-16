#!/usr/bin/env ruby

require "fileutils"
require "erb"
require "rdf/turtle"
require "linkeddata"

require_relative "util.rb"

include ERB::Util

data = load_turtle("textbook.ttl")
curriculums = {}
sitemap = Sitemap.new
sitemap << "/"
sitemap << "/about.html"

data.each do |uri, v|
  p uri
  curriculum = v["https://w3id.org/jp-textbook/curriculum"]
  subject = v["https://w3id.org/jp-textbook/subject"]
  param = {
    uri: uri,
    site_title: "教科書 Linked Open Data (LOD)",
    name: v["http://schema.org/name"],
    editor: v["http://schema.org/editor"],
    publisher: v["http://schema.org/publisher"],
    bookEdition: v["http://schema.org/bookEdition"],
    curriculum: curriculum,
    curriculum_year: curriculum.last_part,
    subject: subject,
    subjectArea: v["https://w3id.org/jp-textbook/subjectArea"],
    subject_name: subject.split(/\//).last.gsub(/%20/, " "),
    subjectArea_name: v["https://w3id.org/jp-textbook/subjectArea"].split(/\//).last.gsub(/%20/, " "),
    grade: v["https://w3id.org/jp-textbook/grade"],
    school: v["https://w3id.org/jp-textbook/school"],
    school_name: v["https://w3id.org/jp-textbook/school"].split(/\//).last,
    textbookSymbol: v["https://w3id.org/jp-textbook/textbookSymbol"],
    textbookNumber: v["https://w3id.org/jp-textbook/textbookNumber"],
    usageYear: v["https://w3id.org/jp-textbook/usageYear"],
    authorizedYear: v["https://w3id.org/jp-textbook/authorizedYear"],
    recorded_by: v["https://w3id.org/jp-textbook/recordedBy"],
    recorded_by_year: v["https://w3id.org/jp-textbook/recordedBy"].split(/\//).last,
    #catalogue_year: v["https://w3id.org/jp-textbook/catalogue"].split(/\//).last,
    recordID: v["http://dl.nier.go.jp/library/vocab/recordID"],
    callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"],
  }
  template = open("template/textbook.html.erb"){|io| io.read }
  file = uri.path.sub(/\A\/jp-textbook\//, "") + ".html"
  FileUtils.mkdir_p(File.dirname(file))
  open(file, "w") do |io|
    io.print ERB.new(template).result(binding)
  end
  sitemap << file

  curriculums[curriculum] ||= {}
  curriculums[curriculum][subject] ||= []
  curriculums[curriculum][subject] << param
end

curriculums.each do |curriculum, e|
  e.each do |subject, textbooks|
    #p subject
    file = curriculum.sub("https://w3id.org/jp-textbook/", "")
    file << "s/#{ subject.last_part }.html"
    p file
    param = {
      curriculum: curriculum,
      curriculum_name: curriculum.last_part,
      startDate_str: curriculum.last_part,
      subject: subject,
      subject_name: subject.last_part,
      textbooks: textbooks,
      school_name: textbooks.first[:school_name],
    }
    template = open("template/textbook-list.html.erb"){|io| io.read }
    FileUtils.mkdir_p(File.dirname(file))
    open(file, "w") do |io|
      io.print ERB.new(template).result(binding)
    end
    sitemap << file
  end
end

open("sitemaps-textbook.xml", "w"){|io| io.print sitemap.to_xml }
