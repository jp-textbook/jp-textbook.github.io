#!/usr/bin/env ruby

require "rdf"
require "linkeddata"

g = RDF::Graph.load("textbook.ttl", format:  :ttl)
textbooks = []
#p g
g.each_triple do |s, v, o|
  textbooks << s
  p s
end
puts textbooks.uniq.size
