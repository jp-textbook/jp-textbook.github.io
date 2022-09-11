#!/usr/bin/env ruby

require "ttl2html"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  filename = find_turtle("all.ttl")
  ttl2html = TTL2HTML::App.new
  data = ttl2html.load_turtle(filename)
  STDERR.puts "loading #{filename}..."
  klass = File
  klass = Zlib::GzipReader if filename =~ /\.ttl\.gz\z/
  klass.open(filename) do |io|
    reader = RDF::Reader.for(:turtle).new(io)
    g = reader.statements
    missing = ( g.subjects - g.objects - g.predicates ).select do |e|
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
    missing = (g.objects - g.subjects).select{|e|
      e.is_a?(RDF::URI) and e.to_s.match(BASE_URI)
    }
    if not missing.empty?
      puts "Missing definition for object(s):"
      missing.sort.each do |object|
        p object
      end
    end
    missing = (g.predicates - g.subjects).select{|e|
      e.is_a?(RDF::URI) and e.to_s.match(BASE_URI)
    }
    if not missing.empty?
      puts "Missing definition for predicate(s):"
      missing.sort.each do |predicate|
        p predicate
      end
    end
  end
end
