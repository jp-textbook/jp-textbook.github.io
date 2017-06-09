#!/usr/bin/env ruby

require "fileutils"
require "erb"
require "rdf/turtle"
require "linkeddata"

require_relative "util.rb"

include ERB::Util

class String
  def unescape_unicode
    self.gsub(/◆U([0-9A-F]+)◆/).each do |c|
      $1.to_i(16).chr("utf-8")
    end
  end
end

data = load_turtle("textbook.ttl")
curriculums = {}
sitemap = Sitemap.new
sitemap << "/"
sitemap << "/about.html"

data.each do |uri, v|
  #p uri
  curriculum = v["https://w3id.org/jp-textbook/curriculum"].first
  subject = v["https://w3id.org/jp-textbook/subject"] ? v["https://w3id.org/jp-textbook/subject"].first : nil
  subject_name = subject ? subject.last_part : nil
  subjectArea = v["https://w3id.org/jp-textbook/subjectArea"].first
  param = {
    uri: uri,
    site_title: "教科書 Linked Open Data (LOD)",
    name: v["http://schema.org/name"].first,
    editor: v["http://schema.org/editor"].first.unescape_unicode,
    publisher: v["http://schema.org/publisher"].first,
    bookEdition: v["http://schema.org/bookEdition"] ? v["http://schema.org/bookEdition"].first : nil,
    curriculum: curriculum,
    curriculum_year: curriculum.last_part,
    subject: subject,
    subjectArea: subjectArea,
    subject_name: subject_name,
    subjectArea_name: subjectArea.last_part,
    grade: v["https://w3id.org/jp-textbook/grade"] ? v["https://w3id.org/jp-textbook/grade"].first : nil,
    school: v["https://w3id.org/jp-textbook/school"].first,
    school_name: v["https://w3id.org/jp-textbook/school"].first.last_part,
    textbookSymbol: v["https://w3id.org/jp-textbook/textbookSymbol"].first,
    textbookNumber: v["https://w3id.org/jp-textbook/textbookNumber"].first,
    usageYear: v["https://w3id.org/jp-textbook/usageYear"].first,
    authorizedYear: v["https://w3id.org/jp-textbook/authorizedYear"].first,
    catalogue: v["https://w3id.org/jp-textbook/catalogue"],
    catalogue_year: v["https://w3id.org/jp-textbook/catalogue"].first.last_part,
    #catalogue_year: v["https://w3id.org/jp-textbook/catalogue"].split(/\//).last,
    note: v["https://w3id.org/jp-textbook/note"] ? v["https://w3id.org/jp-textbook/note"].first : nil,
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
  name = subject_name || subjectArea.last_part
  curriculums[curriculum][name] ||= []
  curriculums[curriculum][name] << param
end

curriculums.sort_by{|k,v| k }.each do |curriculum, e|
  e.sort_by{|k,v| k }.each do |name, textbooks|
    #p subject
    file = curriculum.sub("https://w3id.org/jp-textbook/", "")
    file << "s/#{ name }.html"
    p file
    param = {
      curriculum: curriculum,
      curriculum_name: curriculum.last_part,
      startDate_str: curriculum.last_part,
      subject_name: name,
      textbooks: textbooks.sort_by{|e| [ e[:textbookNumber], e[:uri] ] },
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
