#!/usr/bin/env ruby

require "pathname"
require "rdf/turtle"
require "erb"
require "active_support"
require "nokogiri"
require "lisbn"
require "zlib"

class String
  def last_part
    self.split(/\//).last.gsub(/%20/, " ")
  end
  def squeez_date
    self.gsub(/\d+/){|i| i.to_i }.gsub(/(?<=\D)1年/, "元年")
  end
  def to_year_era
    Date.new(self.to_i).to_era("%O%E年").squeez_date
  end
  def omit_suffix
    self.sub(/\A\//, "").sub(/\/index.html\Z/, "").sub(/\.html\Z/, "")
  end
end

class PageTemplate
  include ERB::Util
  include ActiveSupport::Inflector
  def initialize(template)
    @template = template
    @param = {}
  end
  attr_reader :param
  def output_to(file, param, lang = :ja)
    @param = param
    @param[:output_file] = file
    dir = File.dirname(file)
    FileUtils.mkdir_p(dir) if not File.exist?(dir)
    open(file, "w") do |io|
      io.print to_html(@param, lang)
    end
  end
  def to_html(param, lang = :ja)
    param[:content] = to_html_raw(@template, param, lang)
    layout_fname = "template/layout.html.erb"
    layout_fname = "template/layout.html.#{lang}.erb" if lang != :ja
    to_html_raw(layout_fname, param, lang)
  end
  def to_html_raw(template, param, lang = :ja)
    @param = @param.merge(param)
    tmpl = open(template){|io| io.read }
    erb = ERB.new(tmpl, nil, "-")
    erb.filename = template
    erb.result(binding)
  end

  # helper method:
  def relative_path(dest)
    src = @param[:output_file]
    path = Pathname(dest).relative_path_from(Pathname(File.dirname src))
    path = path.to_s + "/" if File.directory? path
    path
  end
  def relative_path_uri(dest_uri, lang = :ja)
    dest = dest_uri.sub("https://w3id.org/jp-textbook/", "")
    dest = File.join("en", dest) if lang == :en
    relative_path(dest)
  end
end

class Sitemap
  def initialize
    @urlset = []
  end
  def <<(file)
    url = "https://jp-textbook.github.io/#{file.omit_suffix}"
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
  RELATED_LINKS = {
    _waybackmachine: /web.archive.org/,
    _warp: /warp.da.ndl.go.jp/,
    _mext: /mext.go.jp/,
    nier: /nier.go.jp\/guideline\//,
    ncid: /\/ncid\//,
    ndl_jpno: /\/jpno\//,
    ndl_bibid: /ndl.go.jp\/bib\//,
    ndl_search: /iss.ndl.go.jp/,
    ndla: /id.ndl.go.jp\/auth\/ndlna\//,
    dbpedia: /dbpedia.org/,
    hojin_info: /hojin-info\.go\.jp/,
  }
  CURRENT_YEAR= 2019
  def map_links(urls, links)
    urls = [] if urls.nil?
    urls.map{|url|
      key = links.keys.find{|e| links[e].match url }
      p url if key.nil?
      { key: key, url: url }
    }.sort_by{|e| e[:key] }
  end

def find_turtle(filename, params = {})
  if params[:noexpand] == true
    if File.exists? filename
      filename
    end
  else
    file = nil
    basename = File.basename(filename, ".ttl")
    files = Dir.glob("#{basename}-[0-9]*.ttl")
    file = files.sort.last
    file
  end
end

def load_turtle(filename, params = {})
  file = find_turtle(filename, params)
  STDERR.puts "loading #{file}..."
  data = {}
  count = 0
  RDF::Turtle::Reader.open(file) do |reader|
    reader.statements.each do |statement|
      s = statement.subject
      v = statement.predicate
      o = statement.object
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
  end
  STDERR.puts "#{count} triples. #{data.size} subjects."
  data
end

def load_prefixes(filename)
  file = find_turtle(filename)
  prefixes = {}
  open(file) do |io|
    io.each do |line|
      if /\A\s*\@prefix\s+([\w-]+):\s+<(.+?)>\s*\.\s*\z/i =~ line
        prefixes[$1] = $2
      end
    end
  end
  prefixes
end

def expand_shape(data, uri, prefixes = {}, lang = :ja)
  #p uri
  result = data[uri]["http://www.w3.org/ns/shacl#property"].sort_by do |e|
    e["http://www.w3.org/ns/shacl#order"]
  end.map do |property|
    path = data[property]["http://www.w3.org/ns/shacl#path"].first
    shorten_path = path.dup
    prefixes.each do |prefix, val|
      if path.index(val) == 0
        shorten_path = path.sub(/\A#{val}/, "#{prefix}:")
      end
    end
    repeatable = false
    if data[property]["http://www.w3.org/ns/shacl#maxCount"]
      max_count = data[property]["http://www.w3.org/ns/shacl#maxCount"].first.to_i
      if max_count > 1
        repeatable = true
      end
    else
      repeatable = true
    end
    nodes = nil
    if data[property]["http://www.w3.org/ns/shacl#node"]
      node = data[property]["http://www.w3.org/ns/shacl#node"].first
      if data[node]["http://www.w3.org/ns/shacl#or"]
        node_or = data[data[node]["http://www.w3.org/ns/shacl#or"].first]
        node_mode = :or
        nodes = []
        nodes << expand_shape(data, node_or["http://www.w3.org/1999/02/22-rdf-syntax-ns#first"].first, prefixes, lang)
        rest = node_or["http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"].first
        while data[rest] do
          nodes << expand_shape(data, data[rest]["http://www.w3.org/1999/02/22-rdf-syntax-ns#first"].first, prefixes, lang)
          rest = data[rest]["http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"].first
        end
      else
        nodes = expand_shape(data, node, prefixes, lang)
      end
      #p nodes
    end
    {
      path: path,
      shorten_path: shorten_path,
      name_ja: data[property]["http://www.w3.org/ns/shacl#name"][:ja],
      name_en: data[property]["http://www.w3.org/ns/shacl#name"][:en],
      example: data[property]["http://www.w3.org/2004/02/skos/core#example"] ? data[property]["http://www.w3.org/2004/02/skos/core#example"].first : nil,
      description_ja: data[property]["http://www.w3.org/ns/shacl#description"] ? data[property]["http://www.w3.org/ns/shacl#description"][:ja] : nil,
      description_en: data[property]["http://www.w3.org/ns/shacl#description"] ? data[property]["http://www.w3.org/ns/shacl#description"][:en] : nil,
      required: data[property]["http://www.w3.org/ns/shacl#minCount"] ? data[property]["http://www.w3.org/ns/shacl#minCount"].first.to_i > 0 : false,
      repeatable: repeatable,
      nodeKind: data[property]["http://www.w3.org/ns/shacl#nodeKind"] ? data[property]["http://www.w3.org/ns/shacl#nodeKind"].first : nil,
      nodes: nodes,
      node_mode: node_mode,
    }
  end
  if lang == :en
    template = "template/shape-table.html.en.erb"
  else
    template = "template/shape-table.html.erb"
  end
  tmpl = PageTemplate.new(template)
  tmpl.to_html_raw(template, {properties: result}, lang)
end

def load_idlists(*files)
  hash = {}
  files.each do |file|
    STDERR.puts "loading #{file}..."
    open(file) do |io|
      io.gets
      io.each do |line|
        ndlbib, jpno, isbn_list, pid, = line.chomp.split(/\t/)
        if isbn_list and not isbn_list.empty?
          isbn_list.split(/,/).each do |isbn|
            hash[isbn] ||= {
              ndlbib: [],
              jpno: [],
              pid: [],
            }
            ndlbib.split(/,/).uniq.each do |ndlbib_id|
              hash[isbn][:ndlbib] << ndlbib_id
            end
            jpno.split(/,/).uniq.each do |jpno_id|
              hash[isbn][:jpno] << jpno_id
            end
            if pid
              pid.split(/,/).uniq.each do |pid_id|
                hash[isbn][:pid] << pid_id
              end
            end
            hash[isbn][:ndlbib].uniq!
            hash[isbn][:jpno].uniq!
            hash[isbn][:pid].uniq!
          end
        end
      end
    end
  end
  hash
end
def load_books_rdf(file)
  hash = {}
  ncid = nil
  isbn = []
  io = nil
  case file
  when /\.gz\Z/
    f = File.open(file)
    io = Zlib::GzipReader.new(f)
  else
    io = File.open(file)
  end
  STDERR.puts "loading #{file}..."
  reader = Nokogiri::XML::Reader(io)
  reader.each do |node|
    if node.name == "rdf:Description" and node.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT
      if ncid and not isbn.empty?
        isbn.each do |e|
          isbn13 = Lisbn.new(e).isbn13
          hash[isbn13] = ncid
        end
      end
      ncid = nil
      isbn = []
    elsif node.name == "cinii:ncid" and node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
      ncid = node.inner_xml
    elsif node.name == "dcterms:hasPart" and node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
      #<dcterms:hasPart rdf:resource="urn:isbn:9784889241778"/>
      if node.attributes["resource"] and node.attributes["resource"].match(/\Aurn:isbn:(\w+)\z/)
        isbn << $1
      end
    end
  end
  hash
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
  elsif value.is_a? Integer
    str = value
  elsif value =~ /\Ahttps?:\/\//
    str = %Q|<#{value}>|
  else
    str = %Q|"#{value}"|
  end
  str
end
def format_property(property, value)
  if value.is_a? Array
    value = value.sort_by{|e|
      format_pvalue(e)
    }.map do |e|
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
