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
subjects = load_turtle("subject.ttl")
area_data = load_turtle("subjectArea.ttl")
school_data = load_turtle("school.ttl")
curriculums = {}
template = PageTemplate.new("template/textbook.html.erb")
template_en = PageTemplate.new("template/textbook.html.en.erb")
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
  subject_name = subject.last_part if subject
  #p subject
  #p subjects[subject]
  subject_name_en = subjects[subject]["http://schema.org/name"][:en] if subject and subjects[subject] # FIXME: correct subject name. #217
  subjectArea = v["https://w3id.org/jp-textbook/subjectArea"].first
  school = v["https://w3id.org/jp-textbook/school"].first
  param = {
    uri: uri,
    file: uri.sub("https://w3id.org/jp-textbook/", "") + ".html",
    file_en: uri.sub("https://w3id.org/jp-textbook/", "en/") + ".html",
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
    subject_name_en: subject_name_en,
    subjectArea_name: subjectArea.last_part,
    subjectArea_name_en: area_data[subjectArea]["http://schema.org/name"][:en],
    grade: v["https://w3id.org/jp-textbook/grade"] ? v["https://w3id.org/jp-textbook/grade"].first : nil,
    school: v["https://w3id.org/jp-textbook/school"].first,
    school_name: school.last_part,
    school_name_en: school_data[school]["http://schema.org/name"][:en],
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
  FileUtils.mkdir_p(File.dirname(param[:file]))
  open(param[:file], "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << param[:file]
  param[:style] = File.join("..", param[:style])
  FileUtils.mkdir_p(File.dirname(param[:file_en]))
  open(param[:file_en], "w") do |io|
    io.print template_en.to_html(param, :en)
  end
  sitemap << param[:file_en]

  curriculums[curriculum] ||= {}
  if subject
    curriculums[curriculum][subject] ||= []
    curriculums[curriculum][subject] << param
  else
    curriculums[curriculum][subjectArea] ||= []
    curriculums[curriculum][subjectArea] << param
  end
end

template = PageTemplate.new("template/subject.html.erb")
template_en = PageTemplate.new("template/subject.html.en.erb")
subjects.sort_by{|k,v| k }.each do |subject, v|
#curriculums.sort_by{|k,v| k }.each do |curriculum, e|
#  e.sort_by{|k,v| k }.each do |subject, textbooks|
#    next if not subjects.has_key? subject
  #p v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  next if not v.has_key? "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  school = v["https://w3id.org/jp-textbook/school"].first
  school_name = school.last_part
  school_name_en = school_data[school]["http://schema.org/name"][:en]
  curriculum = subject.sub(/\/[^\/]+\/[^\/]+\Z/, "")
  textbooks = curriculums[curriculum][subject]
  textbooks = [] if textbooks.nil?
  subject_area = subject.sub(/\/[^\/]+\Z/, "")
  param = {
    uri: subject,
    file: subject.sub("https://w3id.org/jp-textbook/", "") + ".html",
    file_en: subject.sub("https://w3id.org/jp-textbook/", "en/") + ".html",
    style: "../../../../style.css",
    name: [ school_name, subject.last_part ].join(" "),
    curriculum: curriculum,
    startDate_str: curriculum.last_part,
    subject_name: subject.last_part,
    subject_name_en: v["http://schema.org/name"][:en],
    subject_name_yomi: v["http://schema.org/name"][:"ja-hira"],
    subjectArea: subject_area,
    subjectArea_name: subject_area.last_part,
    subjectArea_name_en: area_data[subject_area]["http://schema.org/name"][:en],
    textbooks: textbooks.sort_by{|t| [ t[:textbookNumber], t[:uri] ] },
    school: school,
    school_name: school_name,
    school_name_en: school_name_en,
    citation: v["http://schema.org/citation"].first,
    seeAlso: v["http://www.w3.org/2000/01/rdf-schema#seeAlso"],
  }
  FileUtils.mkdir_p(File.dirname(param[:file]))
  open(param[:file], "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << param[:file]
  param[:style] = "../" + param[:style]
  param[:name] = "#{param[:subject_name_en]} in #{school_name_en}"
  FileUtils.mkdir_p(File.dirname(param[:file_en]))
  open(param[:file_en], "w") do |io|
    io.print template_en.to_html(param, :en)
  end
  sitemap << param[:file_en]
#  end
end

data = load_turtle("curriculum.ttl")
data_version = load_turtle("curriculum-versions.ttl")
template = PageTemplate.new("template/curriculum.html.erb")
template_en = PageTemplate.new("template/curriculum.html.en.erb")
template_area = PageTemplate.new("template/subject-area.html.erb")
template_area_en = PageTemplate.new("template/subject-area.html.en.erb")
index_param = { subjects: subjects, areas: area_data, active: :home }
param = {}
cur_param = {}
data.each do |uri, v|
  index_param[uri] = []
  school = v["https://w3id.org/jp-textbook/school"].first
  datePublished = Date.parse(v["http://schema.org/datePublished"].first)
  startDate = Date.parse(v["http://schema.org/startDate"].first)
  versions = []
  if data_version[uri]["http://purl.org/dc/terms/hasVersion"]
    versions = data_version[uri]["http://purl.org/dc/terms/hasVersion"].map{|e|
      val = data_version[e]
      date = Date.parse(val["http://schema.org/datePublished"].first)
      {
        name: val["http://schema.org/name"].first,
        datePublished: date,
        datePublished_ymd: date.strftime("%Y年%m月%d日").squeez_date,
        citation: val["http://schema.org/citation"].first,
        url: map_links(val["http://schema.org/url"], Textbook::RELATED_LINKS),
        seeAlso: map_links(val["http://www.w3.org/2000/01/rdf-schema#seeAlso"], Textbook::RELATED_LINKS),
        isbn: val["http://schema.org/isbn"] ? val["http://schema.org/isbn"].first : nil,
        itemID: val["http://dl.nier.go.jp/library/vocab/itemID"] ? val["http://dl.nier.go.jp/library/vocab/itemID"].first : nil,
        callNumber: val["http://dl.nier.go.jp/library/vocab/callNumber"] ? val["http://dl.nier.go.jp/library/vocab/callNumber"].first : nil,
        recordID: val["http://dl.nier.go.jp/library/vocab/recordID"] ? val["http://dl.nier.go.jp/library/vocab/recordID"].first : nil,
      }
    }.sort_by{|e| e[:datePublished] }
  end
  param = {
    uri: uri,
    file: uri.sub("https://w3id.org/jp-textbook/", "") + "/index.html",
    file_en: uri.sub("https://w3id.org/jp-textbook/", "en/") + "/index.html",
    style: "../../../style.css",
    name: v["http://schema.org/name"][:ja],
    name_en: v["http://schema.org/name"][:en],
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    datePublished: datePublished,
    datePublished_ymd: datePublished.strftime("%Y年%m月%d日").squeez_date,
    datePublished_ym: datePublished.strftime("%Y年%m月").squeez_date,
    datePublished_ym_en: datePublished.strftime("%Y-%m"),
    startDate: startDate,
    startDate_ymd: startDate.strftime("%Y年%m月%d日").squeez_date,
    startDate_ym: startDate.strftime("%Y年%m月").squeez_date,
    startDate_ym_en: startDate.strftime("%Y-%m"),
    url: v["http://schema.org/url"].map{|url|
      key = Textbook::RELATED_LINKS.keys.find{|e|
        Textbook::RELATED_LINKS[e].match url
      }
      { key: key, url: url }
    }.sort_by{|e| e[:key] },
    versions: versions,
    subjectArea: [],
    school: school,
    school_name_en: school_data[school]["http://schema.org/name"][:en],
  }
  cur_param[uri] = param
  area_data[uri]["https://w3id.org/jp-textbook/hasSubjectArea"].sort_by{|area|
    area_data[area]["http://purl.org/linked-data/cube#order"].sort.first.to_i
  }.each do |area|
    areas = v["https://w3id.org/jp-textbook/hasSubjectArea"]
    school = area_data[area]["https://w3id.org/jp-textbook/school"].first
    area_param = {
      uri: area,
      file: File.join(area.sub("https://w3id.org/jp-textbook/", ""), "index.html"),
      file_en: File.join(area.sub("https://w3id.org/jp-textbook/", "en/"), "index.html"),
      style: "../../../../style.css",
      curriculum: uri,
      name: area_data[area]["http://schema.org/name"][:ja],
      name_en: area_data[area]["http://schema.org/name"][:en],
      name_yomi: area_data[area]["http://schema.org/name"][:"ja-hira"],
      school: school,
      school_name_en: school_data[school]["http://schema.org/name"][:en],
      subjects: [],
    }
    if subjects[area] and subjects[area]["https://w3id.org/jp-textbook/hasSubject"]
      area_param[:subjects] = subjects[area]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|subject|
        subjects[subject]["http://purl.org/linked-data/cube#order"].sort.first.to_i
      }.map{|subject|
        { uri: subject,
          name: subjects[subject]["http://schema.org/name"][:ja],
          name_en: subjects[subject]["http://schema.org/name"][:en],
        }
      }
    end
    if curriculums[uri][area]
      area_param[:textbooks] = curriculums[uri][area].sort_by{|t| [ t[:textbookNumber], t[:uri] ] }
    end
    param[:subjectArea] << area_param
    dir = File.dirname(area_param[:file])
    FileUtils.mkdir_p(dir) if not File.exist?(dir)
    open(area_param[:file], "w") do |io|
      io.print template_area.to_html(area_param)
    end
    sitemap << area_param[:file]
    dir = File.dirname(area_param[:file_en])
    FileUtils.mkdir_p(dir) if not File.exist?(dir)
    area_param[:style] = File.join("..", area_param[:style])
    open(area_param[:file_en], "w") do |io|
      io.print template_area_en.to_html(area_param, :en)
    end
    sitemap << area_param[:file_en]

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
    if curriculums[uri][area]
      index_param[uri] << area
      STDERR.puts "WARN: Area #{area} is used in a list."
    end
  end
  # curriculum
  dir = File.dirname(param[:file])
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(param[:file], "w") do |io|
    io.print template.to_html(param)
  end
  sitemap << param[:file]
  dir = File.dirname(param[:file_en])
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  param[:style] = File.join("..", param[:style])
  open(param[:file_en], "w") do |io|
    io.print template_en.to_html(param, :en)
  end
end

template = PageTemplate.new("template/school.html.erb")
template_en = PageTemplate.new("template/school.html.en.erb")
school_data.each do |uri, v|
  name = v["http://schema.org/name"][:ja]
  curs = curriculums.keys.sort.reverse.select do |cur_uri|
    cur_uri.match name
  end.map do |cur_uri|
    cur_param[cur_uri]
  end
  file = uri.sub("https://w3id.org/jp-textbook/", "")
  file << ".html"
  param = {
    uri: uri,
    style: "../style.css",
    file: file,
    file_en: File.join("en", file),
    name: name,
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    name_en: v["http://schema.org/name"][:en],
    sameAs: v["http://www.w3.org/2002/07/owl#sameAs"].first,
    curriculums: curs,
  }
  sitemap << param[:file]
  dir = File.dirname(param[:file])
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(param[:file], "w") do |io|
    io.print template.to_html(param)
  end
  param[:style] = File.join("..", param[:style])
  sitemap << param[:file_en]
  dir = File.dirname(param[:file_en])
  FileUtils.mkdir_p(dir) if not File.exist?(dir)
  open(param[:file_en], "w") do |io|
    io.print template_en.to_html(param, :en)
  end
end

doc = Nokogiri::HTML(open "about.html")
index_param[:download] = doc.css("#history + dl dd ul > li").find{|e| e.to_s =~ /all-\d+\.ttl/ }
p index_param[:download]
template = PageTemplate.new("template/index.html.erb")
index_param[:style] = "style.css"
open("index.html", "w") do |io|
  io.print template.to_html(index_param)
end
doc = Nokogiri::HTML(open "en/about.html")
index_param[:download] = doc.css("#history + dl dd ul > li").find{|e| e.to_s =~ /all-\d+\.ttl/ }
p index_param[:download]
template = PageTemplate.new("template/index.html.en.erb")
index_param[:style] = "../style.css"
open("en/index.html", "w") do |io|
  io.print template.to_html(index_param, :en)
end

open("sitemaps-textbook.xml", "w"){|io| io.print sitemap.to_xml }
