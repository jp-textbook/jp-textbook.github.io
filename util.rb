#!/usr/bin/env ruby

require "rdf/turtle"
require "erb"

class String
  def last_part
    self.split(/\//).last.gsub(/%20/, " ")
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
    file = file.sub(/\A\//, "").sub(/\.html\Z/, "")
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

def find_turtle(filename)
  file = nil
  if File.exist? filename and File.file? filename
    file = filename
  else
    basename = File.basename(filename, ".ttl")
    files = Dir.glob("#{basename}-*.ttl")
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
    data[s.to_s][v.to_s] ||= []
    data[s.to_s][v.to_s] << o.to_s
  end
  STDERR.puts "#{count} triples. #{data.size} subjects."
  data
end
