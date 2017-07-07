#!/usr/bin/env ruby

require "fileutils"
require "nokogiri"

require_relative "util.rb"

class String
  def unescape_unicode
    self.gsub(/◆U([0-9A-F]+)◆/).each do |c|
      $1.to_i(16).chr("utf-8")
    end
  end
end

data = load_turtle("textbook.ttl")
curriculums = {}
template = PageTemplate.new("template/textbook.html.erb")
sitemap = Sitemap.new
sitemap << "/"
sitemap << "/about.html"

#p data
data.each do |uri, v|
  #p uri
  next if v["https://w3id.org/jp-textbook/curriculum"].nil?
  #p v["https://w3id.org/jp-textbook/item"]
  curriculum = v["https://w3id.org/jp-textbook/curriculum"].first
  subject = v["https://w3id.org/jp-textbook/subject"] ? v["https://w3id.org/jp-textbook/subject"].first : nil
  subject_name = subject ? subject.last_part : nil
  subjectArea = v["https://w3id.org/jp-textbook/subjectArea"].first
  param = {
    uri: uri,
    style: "../../../style.css",
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
    #recordID: v["http://dl.nier.go.jp/library/vocab/recordID"],
    #callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"],
  }
  param[:item] = v["https://w3id.org/jp-textbook/item"].sort_by{|item|
    data[item]["http://dl.nier.go.jp/library/vocab/recordID"]
  }.map{|item|
    {
      recordID: data[item]["http://dl.nier.go.jp/library/vocab/recordID"].first,
      callNumber: data[item]["http://dl.nier.go.jp/library/vocab/callNumber"].first,
    }
  }
  file = uri.sub("https://w3id.org/jp-textbook/", "") + ".html"
  FileUtils.mkdir_p(File.dirname(file))
  open(file, "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << file

  curriculums[curriculum] ||= {}
  if subject
    curriculums[curriculum][subject] ||= []
    curriculums[curriculum][subject] << param
  else
    curriculums[curriculum][subjectArea] ||= []
    curriculums[curriculum][subjectArea] << param
  end
end

subjects = load_turtle("subject.ttl")
template = PageTemplate.new("template/subject.html.erb")
subjects.sort_by{|k,v| k }.each do |subject, v|
#curriculums.sort_by{|k,v| k }.each do |curriculum, e|
#  e.sort_by{|k,v| k }.each do |subject, textbooks|
#    next if not subjects.has_key? subject
  p subject
  #p v
  #p v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  next if not v.has_key? "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  file = subject.sub("https://w3id.org/jp-textbook/", "")
  file << ".html"
  p file
  school_name = v["https://w3id.org/jp-textbook/school"].first.last_part
  curriculum = subject.sub(/\/[^\/]+\/[^\/]+\Z/, "")
  textbooks = curriculums[curriculum][subject]
  textbooks = [] if textbooks.nil?
  subject_area = subject.sub(/\/[^\/]+\Z/, "")
  param = {
    uri: subject,
    name: [ school_name, subject.last_part ].join(" "),
    curriculum: curriculum,
    startDate_str: curriculum.last_part,
    subject_name: subject.last_part,
    subjectArea: subject_area,
    subjectArea_name: subject_area.last_part,
    textbooks: textbooks.sort_by{|t| [ t[:textbookNumber], t[:uri] ] },
    school_name: school_name,
    citation: v["http://schema.org/citation"].first,
  }
  FileUtils.mkdir_p(File.dirname(file))
  open(file, "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << file
#  end
end

data = load_turtle("subjectArea.ttl")
param = {}
data.keys.select{|uri| data[uri].has_key? "https://w3id.org/jp-textbook/hasSubjectArea" }.each do |uri|
  param[uri] = []
  v = data[uri]
  areas = v["https://w3id.org/jp-textbook/hasSubjectArea"]
  areas.sort_by{|e|
    data[e]["http://purl.org/linked-data/cube#order"].sort_by{|i| i.to_i }.first.to_i
  }.each do |area|
    count_subjects = 0
    if subjects[area]
      subjects[area]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|subject|
        subjects[subject]["http://purl.org/linked-data/cube#order"].first.to_i
      }.each do |subject|
        subject_type = subjects[subject]["https://w3id.org/jp-textbook/subjectType"]
        #p [area, subject, subject_type]
        if curriculums[uri][subject]
          param[uri] << subject
          count_subjects += 1
        else
          if subject_type and subject_type == ["https://w3id.org/jp-textbook/curriculum/Subject/Special"] #ignore special subject.
          else
            STDERR.puts "WARN: #{subject} is not found in subjects list."
          end
        end
      end
    end
    if count_subjects == 0 and curriculums[uri][area]
      param[uri] << area
      STDERR.puts "WARN: Area #{area} is used in a list."
    end
  end
end
doc = Nokogiri::HTML(open "about.html")
param[:download] = doc.css("#history + dl dd ul > li").first
p param[:download]
template = PageTemplate.new("template/index.html.erb")
open("index.html", "w") do |io|
  io.print template.to_html(param)
end

open("sitemaps-textbook.xml", "w"){|io| io.print sitemap.to_xml }
