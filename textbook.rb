#!/usr/bin/env ruby

require "fileutils"
require "nokogiri"
require "era_ja"
require 'ruby-progressbar'

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
publisher_data = load_turtle("publisher.ttl")
publishers = {}
curriculums = {}
template = PageTemplate.new("template/textbook.html.erb")
template_en = PageTemplate.new("template/textbook.html.en.erb")
sitemap = Sitemap.new
sitemap << "/"
sitemap << "/about.html"
sitemap << "/en/"
sitemap << "/en/about.html"

using ProgressBar::Refinements::Enumerator

#p data
data.each.with_progressbar(format: "%a %e %P% Processed: %c from %C") do |uri, v|
  #p uri
  next if v["https://w3id.org/jp-textbook/curriculum"].nil?
  curriculum = v["https://w3id.org/jp-textbook/curriculum"].first
  subject = v["https://w3id.org/jp-textbook/subject"] ? v["https://w3id.org/jp-textbook/subject"].first : nil
  subject_name = subject.last_part if subject
  subject_name_en = subjects[subject]["http://schema.org/name"][:en] if subject and subjects[subject] # FIXME: correct subject name. #217
  subjectArea = v["https://w3id.org/jp-textbook/subjectArea"].first
  school = v["https://w3id.org/jp-textbook/school"].first
  publisher_list = v["http://schema.org/publisher"].sort.map do |e|
    warn "publisher [#{e}] not found in publisher.ttl." if not publisher_data[e]
    { uri: e,
      name: publisher_data[e]["http://schema.org/name"][:ja],
      name_yomi: publisher_data[e]["http://schema.org/name"][:"ja-hira"],
    }
  end
  param = {
    uri: uri,
    file: uri.sub("https://w3id.org/jp-textbook/", "") + ".html",
    file_en: uri.sub("https://w3id.org/jp-textbook/", "en/") + ".html",
    name: v["http://schema.org/name"].first,
    editor: v["http://schema.org/editor"].first.unescape_unicode,
    publishers: publisher_list,
    bookEdition: v["http://schema.org/bookEdition"] ? v["http://schema.org/bookEdition"].first : nil,
    curriculum: curriculum,
    curriculum_year: curriculum.last_part,
    subject: subject,
    subjectArea: subjectArea,
    subject_name: subject_name,
    subject_name_en: subject_name_en,
    subjectArea_name: subjectArea.last_part,
    subjectArea_name_en: area_data[subjectArea]["http://schema.org/name"][:en],
    grade: v["https://w3id.org/jp-textbook/grade"] ? v["https://w3id.org/jp-textbook/grade"].sort : nil,
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
    note: v["http://id.loc.gov/ontologies/bibframe/note"] ? v["http://id.loc.gov/ontologies/bibframe/note"].sort: nil,
    extent: v["http://id.loc.gov/ontologies/bibframe/extent"] ? v["http://id.loc.gov/ontologies/bibframe/extent"].first : nil,
    dimensions: v["http://id.loc.gov/ontologies/bibframe/dimensions"] ? v["http://id.loc.gov/ontologies/bibframe/dimensions"].first : nil,
    #recordID: v["http://dl.nier.go.jp/library/vocab/recordID"],
    #callNumber: v["http://dl.nier.go.jp/library/vocab/callNumber"],
  }
  param[:item] = []
  v["https://w3id.org/jp-textbook/item"].sort_by{|item|
    data[item]["http://dl.nier.go.jp/library/vocab/recordID"]
  }.each do |item|
    param[:item] << {
      holding: :nier,
      recordID: data[item]["http://dl.nier.go.jp/library/vocab/recordID"].first,
      callNumber: data[item]["http://dl.nier.go.jp/library/vocab/callNumber"].first,
    }
  end
  if data_rc[uri]
    #p data_rc[uri]
    param[:isbn] = data_rc[uri]["http://schema.org/isbn"].sort
    param[:seeAlso] = map_links(data_rc[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"], Textbook::RELATED_LINKS)
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
  publisher_list.each do |publisher|
    publishers[publisher[:uri]] ||= []
    publishers[publisher[:uri]] << param
  end
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
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
catalogue_data = load_turtle("catalogue.ttl")
template = PageTemplate.new("template/publisher.html.erb")
template_en = PageTemplate.new("template/publisher.html.en.erb")
publisher_group = {}
publisher_data.each do |k, v|
  if v["http://www.w3.org/2000/01/rdf-schema#seeAlso"]
    v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].each do |url|
      publisher_group[url] ||= []
      publisher_group[url] << k
    end
  end
end
publisher_data.each do |uri, v|
  file = uri.sub("https://w3id.org/jp-textbook/", "")
  file << ".html"
  catalogue = []
  if catalogue
    v["https://w3id.org/jp-textbook/catalogue"].sort_by{|c|
      %w[小 中 高].index{|i| c.match(i) }
    }.each do |c|
      warn "catalogue [#{c}] not found in catalogue.ttl." if not catalogue_data[c]
      catalogue << {
        uri: c,
        name: catalogue_data[c]["http://schema.org/name"][:ja],
        name_en: catalogue_data[c]["http://schema.org/name"][:en],
      }
    end
  end
  param = {
    uri: uri,
    file: file,
    file_en: File.join("en", file),
    textbooks: publishers[uri],
    name: v["http://schema.org/name"][:ja],
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    name_latin: v["http://schema.org/name"][:"ja-latn"],
    seeAlso: map_links(v["http://www.w3.org/2000/01/rdf-schema#seeAlso"], Textbook::RELATED_LINKS),
    catalogueYear: v["https://w3id.org/jp-textbook/catalogueYear"].first,
    catalogue: catalogue,
    publisher_abbr: v["https://w3id.org/jp-textbook/publisherAbbreviation"].first,
    publisher_number: v["https://w3id.org/jp-textbook/publisherNumber"],
    note: v["http://id.loc.gov/ontologies/bibframe/note"] ? v["http://id.loc.gov/ontologies/bibframe/note"].first : nil,
  }
  param[:publisher_group] = []
  if v["http://www.w3.org/2000/01/rdf-schema#seeAlso"]
    v["http://www.w3.org/2000/01/rdf-schema#seeAlso"].each do |related_url|
      param[:publisher_group] << publisher_group[related_url]
    end
  end
  param[:publisher_group] = param[:publisher_group].flatten.sort.uniq.map{|e|
    { uri: e,
      year: publisher_data[e]["https://w3id.org/jp-textbook/catalogueYear"].first,
    }
  }
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
end

data_subjectType = load_turtle("subjectType.ttl")
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
  if v["https://w3id.org/jp-textbook/subjectType"]
    subjectTypes = v["https://w3id.org/jp-textbook/subjectType"].sort.map do |subjectType_uri|
      {
        uri: subjectType_uri,
        name: data_subjectType[subjectType_uri]["http://schema.org/name"][:ja],
        name_en: data_subjectType[subjectType_uri]["http://schema.org/name"][:en],
      }
    end
  end
  param = {
    uri: subject,
    file: subject.sub("https://w3id.org/jp-textbook/", "") + ".html",
    file_en: subject.sub("https://w3id.org/jp-textbook/", "en/") + ".html",
    name: [ school_name, subject.last_part ].join(" "),
    name_en: "#{v["http://schema.org/name"][:en]} in #{school_name_en}",
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
    subjectType: subjectTypes,
    order: v["http://purl.org/linked-data/cube#order"].first,
  }
  if v["https://w3id.org/jp-textbook/sourceOfEnglishName"]
    source_of_english_name = subjects[v["https://w3id.org/jp-textbook/sourceOfEnglishName"].first]
    param[:source_of_english_name] = {
      name: source_of_english_name["http://schema.org/name"][:ja],
      name_en: source_of_english_name["http://schema.org/name"][:en],
      seeAlso: source_of_english_name["http://www.w3.org/2000/01/rdf-schema#seeAlso"].first,
    }
  end
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
#  end
end

data = load_turtle("curriculum.ttl")
data_version = load_turtle("curriculum-versions.ttl")
template = PageTemplate.new("template/curriculum.html.erb")
template_en = PageTemplate.new("template/curriculum.html.en.erb")
template_area = PageTemplate.new("template/subject-area.html.erb")
template_area_en = PageTemplate.new("template/subject-area.html.en.erb")
index_param = {
  file: "index.html", file_en: "en/index.html",
  subjects: subjects, areas: area_data, active: :home,
}
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
        name: val["http://schema.org/name"][:ja],
        name_en: val["http://schema.org/name"][:en],
        datePublished: date,
        datePublished_ymd: date.strftime("%Y年%m月%d日").squeez_date,
        citation: val["http://schema.org/citation"][:ja],
        citation_en: val["http://schema.org/citation"][:en],
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
    if area_data[area]["https://w3id.org/jp-textbook/subjectType"]
      subjectTypes = area_data[area]["https://w3id.org/jp-textbook/subjectType"].sort.map do |subjectType_uri|
        {
          uri: subjectType_uri,
          name: data_subjectType[subjectType_uri]["http://schema.org/name"][:ja],
          name_en: data_subjectType[subjectType_uri]["http://schema.org/name"][:en],
        }
      end
    end
    area_param = {
      uri: area,
      file: File.join(area.sub("https://w3id.org/jp-textbook/", ""), "index.html"),
      file_en: File.join(area.sub("https://w3id.org/jp-textbook/", "en/"), "index.html"),
      curriculum: uri,
      name: area_data[area]["http://schema.org/name"][:ja],
      name_en: area_data[area]["http://schema.org/name"][:en],
      name_yomi: area_data[area]["http://schema.org/name"][:"ja-hira"],
      school: school,
      school_name_en: school_data[school]["http://schema.org/name"][:en],
      subjects: [],
      subjectType: subjectTypes,
      order: area_data[area]["http://purl.org/linked-data/cube#order"].sort_by{|e| e.to_i },
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
    if area_data[area]["https://w3id.org/jp-textbook/sourceOfEnglishName"]
      source_of_english_name = area_data[area_data[area]["https://w3id.org/jp-textbook/sourceOfEnglishName"].first]
      area_param[:source_of_english_name] = {
        name: source_of_english_name["http://schema.org/name"][:ja],
        name_en: source_of_english_name["http://schema.org/name"][:en],
        seeAlso: source_of_english_name["http://www.w3.org/2000/01/rdf-schema#seeAlso"].first,
      }
    end
    param[:subjectArea] << area_param
    template_area.output_to(area_param[:file], area_param)
    sitemap << area_param[:file]
    template_area_en.output_to(area_param[:file_en], area_param, :en)
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
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
end
template = PageTemplate.new("template/subject-type.html.erb")
template_en = PageTemplate.new("template/subject-type.html.en.erb")
data_subjectType.each do |uri, v|
  curriculum = v["https://w3id.org/jp-textbook/curriculum"].first
  school = v["https://w3id.org/jp-textbook/school"].first
  file = uri.sub("https://w3id.org/jp-textbook/", "")
  file << ".html"
  param = {
    uri: uri,
    file: file,
    file_en: File.join("en", file),
    name: v["http://schema.org/name"][:ja],
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    name_en: v["http://schema.org/name"][:en],
    citation: v["http://schema.org/citation"].first,
    curriculum: curriculum,
    curriculum_name: data[curriculum]["http://schema.org/name"][:ja],
    curriculum_name_en: data[curriculum]["http://schema.org/name"][:en],
    school: school,
    school_name: school_data[school]["http://schema.org/name"][:ja],
    school_name_en: school_data[school]["http://schema.org/name"][:en],
  }
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
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
    file: file,
    file_en: File.join("en", file),
    name: name,
    name_yomi: v["http://schema.org/name"][:"ja-hira"],
    name_en: v["http://schema.org/name"][:en],
    sameAs: v["http://www.w3.org/2002/07/owl#sameAs"].first,
    curriculums: curs,
  }
  template.output_to(param[:file], param)
  sitemap << param[:file]
  template_en.output_to(param[:file_en], param, :en)
  sitemap << param[:file_en]
end

doc = Nokogiri::HTML(open "about.html")
index_param[:download] = doc.css("#history + dl dd ul > li").find{|e| e.to_s =~ /all-\d+\.ttl/ }
recent_list = doc.css("#history + dl")
index_param[:recent_history] = {
  date: recent_list.xpath("./dt").first.text,
  description: recent_list.xpath("./dd").first.children.find_all{|e| not e.to_s =~ /all-\d+\.ttl/ }.map{|e| e.to_s }.join.strip,
}
p index_param[:recent_history]
template = PageTemplate.new("template/index.html.erb")
template.output_to("index.html", index_param)

doc = Nokogiri::HTML(open "en/about.html")
index_param[:download] = doc.css("#history + dl dd ul > li").find{|e| e.to_s =~ /all-\d+\.ttl/ }
recent_list = doc.css("#history + dl")
index_param[:recent_history] = {
  date: recent_list.xpath("./dt").first.text,
  description: recent_list.xpath("./dd").first.children.find_all{|e| not e.to_s =~ /all-\d+\.ttl/ }.map{|e| e.to_s }.join.strip,
}
template = PageTemplate.new("template/index.html.en.erb")
template.output_to("en/index.html", index_param, :en)

open("sitemaps-textbook.xml", "w"){|io| io.print sitemap.to_xml }
