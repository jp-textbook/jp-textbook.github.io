#!/usr/bin/env ruby

require "sparql"
require 'ruby-progressbar'
require_relative "util.rb"

bar = ProgressBar.create(format: "%a %e %P% Processed: %c from %C")

include Textbook
data = load_turtle(find_turtle("textbook.ttl"))
bar.total = data.keys.size
file = find_turtle("all.ttl")
STDERR.puts "loading #{file}..."
g = RDF::Graph.load(file, format:  :turtle)

PREFIX = /\Ahttps:\/\/w3id.org\/jp-textbook\//
data.each do |key, val|
  next if not key =~ PREFIX
  #p key
  file = key.sub(PREFIX, "")
  file << ".ttl"
  #p file
  sparql = SPARQL.parse("DESCRIBE <#{key}>")
  g2 = sparql.execute(g)
  open(file, "w") do |io|
    io.puts g2.dump(:turtle).strip
  end
  bar.increment
end
