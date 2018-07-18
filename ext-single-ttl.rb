#!/usr/bin/env ruby

require "sparql"
require_relative "util.rb"

include Textbook
data = load_turtle(find_turtle("textbook.ttl"))
file = find_turtle("all.ttl")
STDERR.puts "loading #{file}..."
g = RDF::Graph.load(file, format:  :turtle)

PREFIX = /\Ahttps:\/\/w3id.org\/jp-textbook\//
data.each do |key, val|
  next if not key =~ PREFIX
  p key
  file = key.sub(PREFIX, "")
  file << ".ttl"
  p file
  sparql = SPARQL.parse("DESCRIBE <#{key}>")
  g2 = sparql.execute(g)
  open(file, "w") do |io|
    io.puts g2.dump(:turtle).strip
  end
end
