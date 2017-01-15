#!/usr/bin/env ruby

class String
  def last_part
    self.split(/\//).last.gsub(/%20/, " ")
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
