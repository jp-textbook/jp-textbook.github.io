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
  dir = File.dirname(file)
  FileUtils.mkdir_p(dir) if not File.exist? dir
  str = RDF::Turtle::Writer.buffer do |writer|
    g.query([subject, nil, nil]).sort_by do |statement|
      [ statement.predicate, statement.object ]
    end.each do |statement|
      writer << statement
      if statement.object.node?
        g.query([statement.object, nil, nil]).sort_by do |s|
          [ s.predicate, s.object ]
        end.each do |s|
          writer << s
        end
      end
    end
  end
  open(file, "w") do |io|
    io.print str.strip
  end
end
