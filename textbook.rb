#!/usr/bin/env ruby

require "fileutils"
require "nokogiri"
require "era_ja"

require_relative "util.rb"

class String
  def unescape_unicode
    self.gsub(/◆U([0-9A-F]+)◆/).each do |c|
      $1.to_i(16).chr("utf-8")
    end
  end
end

include Textbook
data = load_turtle("textbook.ttl")
data_rc = load_turtle("textbook-rc.ttl")
curriculums = {}
template = PageTemplate.new("template/textbook.html.erb")
sitemap = Sitemap.new
sitemap << "/"
sitemap << "/about.html"
sitemap << "/en/"
sitemap << "/en/about.html"

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
    extent: v["http://id.loc.gov/ontologies/bibframe/extent"] ? v["http://id.loc.gov/ontologies/bibframe/extent"].first : nil,
    dimensions: v["http://id.loc.gov/ontologies/bibframe/dimensions"] ? v["http://id.loc.gov/ontologies/bibframe/dimensions"].first : nil,
    #recordID: v["http://dl.nier.go.jp/library/vocab/recordID"],
    #callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"],
  }
  param[:item] = v["https://w3id.org/jp-textbook/item"].sort_by{|item|
    data[item]["http://dl.nier.go.jp/library/vocab/recordID"]
  }.map{|item|
    {
      holding: :nier,
      recordID: data[item]["http://dl.nier.go.jp/library/vocab/recordID"].first,
      callNumber: data[item]["http://dl.nier.go.jp/library/vocab/callNumber"].first,
    }
  }
  if data_rc[uri]
    #p data_rc[uri]
    param[:isbn] = data_rc[uri]["http://schema.org/isbn"].sort
    items = data_rc[uri]["https://w3id.org/jp-textbook/item"]
    items.sort_by{|e| data_rc[e]["http://dl.nier.go.jp/library/vocab/textbook-rc/recordID"] }.each do |item|
      #p [item, data_rc[item]]
      param[:item] << {
        holding: :textbook_rc,
        recordID: data_rc[item]["http://dl.nier.go.jp/library/vocab/textbook-rc/recordID"].first,
        callNumber: data_rc[item]["http://dl.nier.go.jp/library/vocab/textbook-rc/callNumber"].first,
      }
    end
  end
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
    subject_name_yomi: v["http://schema.org/name"][:"ja-hira"],
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

data = load_turtle("curriculum.ttl")
area_data = load_turtle("subjectArea.ttl")
template = PageTemplate.new("template/curriculum.html.erb")
template_area = PageTemplate.new("template/subject-area.html.erb")
index_param = { subjects: subjects, areas: area_data }
param = {}
#data.keys.select{|uri| data[uri].has_key? "https://w3id.org/jp-textbook/hasSubjectArea" }.each do |uri|
data.each do |uri, v|
  index_param[uri] = []
  param = {
    uri: uri,
    style: "../../../style.css",
    name: v["http://schema.org/name"][:ja],
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    datePublished: v["http://schema.org/datePublished"].first,
    startDate: v["http://schema.org/startDate"].first,
    startDate_date: Date.parse(v["http://schema.org/startDate"].first),
    startDate_str: Date.parse(v["http://schema.org/startDate"].first).strftime("%Y年%m月").squeez_date,
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].first,
    subjectArea: [],
    school: v["https://w3id.org/jp-textbook/school"].first,
  }
  area_data[uri]["https://w3id.org/jp-textbook/hasSubjectArea"].sort_by{|area|
    area_data[area]["http://purl.org/linked-data/cube#order"].sort.first.to_i
  }.each do |area|
    p area
    areas = v["https://w3id.org/jp-textbook/hasSubjectArea"]
    area_param = {
      uri: area,
      style: "../../../style.css",
      curriculum: uri,
      name: area_data[area]["http://schema.org/name"][:ja],
      name_yomi: area_data[area]["http://schema.org/name"][:"ja-hira"],
      school: area_data[area]["https://w3id.org/jp-textbook/school"].first,
      subjects: [],
    }
    if subjects[area] and subjects[area]["https://w3id.org/jp-textbook/hasSubject"]
      area_param[:subjects] = subjects[area]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|subject|
        subjects[subject]["http://purl.org/linked-data/cube#order"].sort.first.to_i
      }
    end
    if curriculums[uri][area]
      area_param[:textbooks] = curriculums[uri][area].sort_by{|t| [ t[:textbookNumber], t[:uri] ] }
    end
    param[:subjectArea] << area_param
    file = File.join(area.sub("https://w3id.org/jp-textbook/", ""), "index.html")
    p file
    dir = File.dirname(file)
    FileUtils.mkdir_p(dir) if not File.exist?(dir)
    open(file, "w") do |io|
      io.print template_area.to_html(area_param)
    end
    sitemap << file

    count_subjects = 0
    if subjects[area]
      subjects[area]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|subject|
        subjects[subject]["http://purl.org/linked-data/cube#order"].first.to_i
      }.each do |subject|
        subject_type = subjects[subject]["https://w3id.org/jp-textbook/subjectType"]
        #p [area, subject, subject_type]
        if curriculums[uri][subject]
          index_param[uri] << subject
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
      index_param[uri] << area
      STDERR.puts "WARN: Area #{area} is used in a list."
    end
  end
  # curriculum
  file = File.join(uri.sub("https://w3id.org/jp-textbook/", ""), "index.html")
  p file
  dir = File.dirname(file)
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(file, "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << file
end
doc = Nokogiri::HTML(open "about.html")
index_param[:download] = doc.css("#history + dl dd ul > li").find{|e| e.to_s =~ /all-\d+\.ttl/ }
p index_param[:download]
template = PageTemplate.new("template/index.html.erb")
open("index.html", "w") do |io|
  io.print template.to_html(index_param)
end
doc = Nokogiri::HTML(open "en/about.html")
index_param[:download] = doc.css("#history + dl dd ul > li").find{|e| e.to_s =~ /all-\d+\.ttl/ }
p index_param[:download]
template = PageTemplate.new("template/index.html.en.erb")
open("en/index.html", "w") do |io|
  io.print template.to_html(index_param, :en)
end

open("sitemaps-textbook.xml", "w"){|io| io.print sitemap.to_xml }
