#!/usr/bin/env ruby

require "ttl2html"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  data = nil
  ttl2html = TTL2HTML::App.new
  graph = RDF::Graph.new
  ["all-textbook.ttl", "all-teachingUnit.ttl"].each do |filename|
    ttl_filename = find_turtle(filename)
    data = ttl2html.load_turtle(ttl_filename)
    klass = File
    klass = Zlib::GzipReader if ttl_filename =~ /\.ttl\.gz\z/
    klass.open(ttl_filename) do |io|
      reader = RDF::Reader.for(:turtle).new(io)
      graph << reader
    end
  end
  missing = ( graph.subjects - graph.objects - graph.predicates ).select do |e|
    e.is_a?(RDF::URI) and e.to_s.match(BASE_URI)
  end
  if not missing.empty?
    puts "Missing usage for subject(s):"
    missing.sort.each do |subject|
      rdf_type = data[subject.to_s][RDF.type.to_s]&.first
      #rdf_type = g.first_object(subject: subject, predicate: RDF.type)
      next if rdf_type and rdf_type == RDF::URI("https://w3id.org/jp-textbook/Textbook")
      next if rdf_type and rdf_type == RDF::URI("https://w3id.org/jp-textbook/TeachingUnit")
      p subject
    end
  end
  missing = (graph.objects - graph.subjects).select{|e|
    e.is_a?(RDF::URI) and e.to_s.match(BASE_URI)
  }
  if not missing.empty?
    puts "Missing definition for object(s):"
    missing.sort.each do |object|
      p object
    end
  end
  missing = (graph.predicates - graph.subjects).select{|e|
    e.is_a?(RDF::URI) and e.to_s.match(BASE_URI)
  }
  if not missing.empty?
    puts "Missing definition for predicate(s):"
    missing.sort.each do |predicate|
      p predicate
    end
  end
end
