#!/usr/bin/env ruby

require "rdf/turtle"
require "erb"

class String
  def last_part
    self.split(/\//).last.gsub(/%20/, " ")
  end
  def squeez_date
    self.gsub(/\d+/){|i| i.to_i }
  end
  def to_year_era
    Date.new(self.to_i).to_era("%O%E").squeez_date + "年"
  end
end

class PageTemplate
  include ERB::Util
  def initialize(template)
    @template = template
  end
  def to_html(param)
    tmpl = open(@template){|io| io.read }
    erb = ERB.new(tmpl, $SAFE, "-")
    erb.filename = @template
    param[:content] = erb.result(binding)
    layout = open("template/layout.html.erb"){|io| io.read }
    erb = ERB.new(layout, $SAFE, "-")
    erb.filename = "template/layout.html.erb"
    erb.result(binding)
  end
end

class Sitemap
  def initialize
    @urlset = []
  end
  def <<(file)
    file = file.sub(/\A\//, "").sub(/\/index.html\Z/, "").sub(/\.html\Z/, "")
    url = "https://jp-textbook.github.io/#{file}"
    @urlset << url
  end
  def to_xml
    result = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
EOF
    @urlset.sort.each do |url|
      result << "<url><loc>#{url}</loc></url>\n"
    end
    result << "</urlset>"
    result
  end
end

module Textbook
  BASE_URI = "https://w3id.org/jp-textbook"
  PROPERTY_LABEL = {
    "schema:name" => "書名",
    "schema:editor" => "編著者",
    "schema:publisher" => "出版社",
    "schema:bookEdition" => "版",
    "textbook:grade" => "学年",
  }

def find_turtle(filename)
  file = nil
  if File.exist? filename and File.file? filename
    file = filename
  else
    basename = File.basename(filename, ".ttl")
    files = Dir.glob("#{basename}-[0-9]*.ttl")
    file = files.sort.last
  end
  file
end

def load_turtle(filename)
  file = find_turtle(filename)
  STDERR.puts "loading #{file}..."
  g = RDF::Graph.load(file, format:  :turtle)
  data = {}
  count = 0
  g.each do |s, v, o|
    count += 1
    data[s.to_s] ||= {}
    if o.respond_to?(:has_language?) and o.has_language?
      data[s.to_s][v.to_s] ||= {}
      data[s.to_s][v.to_s][o.language] = o.to_s
    else
      data[s.to_s][v.to_s] ||= []
      data[s.to_s][v.to_s] << o.to_s
    end
  end
  STDERR.puts "#{count} triples. #{data.size} subjects."
  data
end

def compare_ignorespaces(str1, str2)  # 氏名等を空白を無視して比較する
  str1.to_s.gsub(/[\s,]+/, "") == str2.to_s.gsub(/[\s,]+/, "")
end

def format_pvalue(value)
  str = ""
  if value.is_a? Hash
    result = ["["]
    array = []
    value.keys.sort.each do |k|
      array << format_property(k, value[k])
    end
    result << array.join(";\n")
    result << "  ]"
    str = result.join("\n")
  elsif value =~ /\Ahttps?:\/\//
    str = %Q|<#{value}>|
  else
    str = %Q|"#{value}"|
  end
  str
end
def format_property(property, value)
  if value.is_a? Array
    value = value.map do |e|
      format_pvalue(e)
    end
    %Q|  #{property} #{ value.join(", ") }|
  else
    value = format_pvalue(value)
    %Q|  #{property} #{value}|
  end
end

def map_xlsx_row_headers(data_row, headers)
  hash = {}
  headers.each_with_index do |h, idx|
    hash[h] = data_row[idx].to_s
  end
  hash
end
end
