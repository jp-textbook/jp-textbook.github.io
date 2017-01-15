#!/usr/bin/env ruby

require "fileutils"
require "erb"
require "rdf/turtle"
require "linkeddata"

include ERB::Util

g = RDF::Graph.load("textbook.ttl", format:  :ttl)
data = {}
g.each do |s, v, o|
  data[s] ||= {}
  data[s][v.to_s] = o.to_s
end
p data.keys.size

data.each do |uri, v|
  p uri
  param = {
    uri: uri,
    site_title: "教科書 Linked Open Data (LOD)",
    title: v["http://schema.org/title"],
    editor: v["http://schema.org/editor"],
    publisher: v["http://schema.org/publisher"],
    subject: v["https://w3id.org/jp-textbook/subject"],
    subjectArea: v["https://w3id.org/jp-textbook/subjectArea"],
    subject_name: v["https://w3id.org/jp-textbook/subject"].split(/\//).last,
    subjectArea_name: v["https://w3id.org/jp-textbook/subjectArea"].split(/\//).last,
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
  }
  template = open("template/textbook.html.erb"){|io| io.read }
  file = uri.path.sub(/\A\/jp-textbook\//, "") + ".html"
  FileUtils.mkdir_p(File.dirname(file))
  open(file, "w") do |io|
    io.print ERB.new(template).result(binding)
  end
end
