#!/usr/bin/env ruby

class String
  def last_part
    self.split(/\//).last.gsub(/%20/, " ")
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
    @urlset.each do |url|
      result << "<url><loc>#{url}</loc></url>\n"
    end
    result << "</urlset>"
    result
  end
end

def load_turtle(filename)
  file = nil
  if File.exist? filename
    file = filename
  else
    basename = File.basename(filename, ".ttl")
    files = Dir.glob("#{basename}-*.ttl")
    file = files.sort.last
  end
  STDERR.puts "loading #{file}..."
  g = RDF::Graph.load(file, format:  :ttl)
  data = {}
  g.each do |s, v, o|
    data[s] ||= {}
    data[s][v.to_s] = o.to_s
  end
  data
end
