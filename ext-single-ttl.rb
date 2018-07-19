#!/usr/bin/env ruby

require "sparql"
require 'ruby-progressbar'
require_relative "util.rb"

bar = ProgressBar.create(format: "%a %e %P% Processed: %c from %C")

include Textbook
file = find_turtle("all.ttl")
STDERR.puts "loading #{file}..."
g = RDF::Graph.load(file, format:  :turtle)
bar.total = g.subjects.size

PREFIX = /\Ahttps:\/\/w3id.org\/jp-textbook\//
g.subjects.each do |subject|
  uri = subject.to_s
  if not uri =~ PREFIX
    bar.total -= 1
    next
  end
  file = uri.sub(PREFIX, "")
  file << ".ttl"
  sparql = SPARQL.parse("DESCRIBE <#{uri}>")
  g2 = sparql.execute(g)
  open(file, "w") do |io|
    io.puts g2.dump(:turtle).strip
  end
  bar.increment
end
