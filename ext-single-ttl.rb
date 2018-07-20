#!/usr/bin/env ruby

require "fileutils"
require "sparql"
require 'ruby-progressbar'
require_relative "util.rb"

using ProgressBar::Refinements::Enumerator

include Textbook
file = find_turtle("all.ttl")
STDERR.puts "loading #{file}..."
g = RDF::Graph.load(file, format:  :turtle)

PREFIX = /\Ahttps:\/\/w3id.org\/jp-textbook\//
g.subjects.each.with_progressbar(format: "%a %e %P% Processed: %c from %C") do |subject|
  uri = subject.to_s
  next if not uri =~ PREFIX
  file = uri.sub(PREFIX, "")
  file << ".ttl"
  sparql = SPARQL.parse("DESCRIBE <#{uri}>")
  g2 = sparql.execute(g)
  dir = File.dirname(file)
  FileUtils.mkdir_p(dir) if not File.exist? dir
  open(file, "w") do |io|
    io.puts g2.dump(:turtle).strip
  end
end
