#!/usr/bin/env ruby

require "fileutils"
require "erb"
require "rdf/turtle"
require "linkeddata"
require "nokogiri"

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
    catalogue_year: v["https://w3id.org/jp-textbook/catalogue"].sort.first.last_part,
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

data = load_turtle("subjectArea.ttl")
subjects = load_turtle("subject.ttl")
param = {}
done = {}
data.keys.select{|uri| data[uri].has_key? "https://w3id.org/jp-textbook/hasSubjectArea" }.each do |uri|
  uri_s = uri.to_s
  param[uri_s] = []
  v = data[uri]
  areas = v["https://w3id.org/jp-textbook/hasSubjectArea"]
  areas.sort_by{|e|
    area_uri = RDF::URI.new(e)
    data[area_uri]["http://purl.org/linked-data/cube#order"].sort_by{|i| i.to_i }.first.to_i
  }.each do |area|
    p uri
    key = [uri_s, area.last_part]
    if curriculums[uri_s][area.last_part] and not done[key]
      param[uri_s] << area.last_part
      done[key] = true
    else
      STDERR.puts "WARN: #{area} is duplicate or not found in subjects list."
    end
    area_uri = RDF::URI.new(area)
    if subjects[area_uri]
     # next if area =~ /高等学校/ and data[area_uri]["https://w3id.org/jp-textbook/subjectAreaType"].first == "https://w3id.org/jp-textbook/curriculum/SubjectArea/Special"
      subjects[area_uri]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|s|
        subject_uri = RDF::URI.new(s)
        subjects[subject_uri]["http://purl.org/linked-data/cube#order"].first.to_i
      }.each do |subject|
        key = [uri_s, subject.last_part]
        if curriculums[uri_s][subject.last_part] and not done[key]
          param[uri_s] << subject.last_part
          done[key] = true
        else
          STDERR.puts "WARN: #{subject} is duplicate or not found in subjects list."
        end
      end
    else
    end
  end
end
doc = Nokogiri::HTML(open "about.html")
param[:download] = doc.css("#history + dl dd ul > li").first
template = open("template/index.html.erb"){|io| io.read }
open("index.html", "w") do |io|
  io.print ERB.new(template, $SAFE, "-").result(binding)
end
p param

open("sitemaps-textbook.xml", "w"){|io| io.print sitemap.to_xml }
