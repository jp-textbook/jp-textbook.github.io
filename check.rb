#!/usr/bin/env ruby

require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  filename = find_turtle("all.ttl")
  STDERR.puts "loading #{filename}..."
  g = RDF::Graph.load(filename, format: :turtle)
  puts "Missing usage for subject(s):"
  ( g.subjects - g.objects ).sort.each do |subject|
    next if not subject.to_s.match(BASE_URI)
    rdf_type = g.query([subject, RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), nil]).first.object
    next if rdf_type == RDF::URI("https://w3id.org/jp-textbook/Textbook")
    p subject
  end
  puts "Missing definition for object(s):"
  ( g.objects - g.subjects ).sort.each do |object|
    next if not object.to_s.match(BASE_URI)
    p object
  end
  puts "Missing definition for predicate(s):"
  ( g.predicates - g.subjects ).sort.each do |predicate|
    next if not predicate.to_s.match(BASE_URI)
    p predicate
  end
end
