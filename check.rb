#!/usr/bin/env ruby

require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  filename = find_turtle("all.ttl")
  STDERR.puts "loading #{filename}..."
  g = RDF::Graph.load(filename, format: :turtle)
  missing = ( g.subjects - g.objects - g.predicates ).select{|e|
    e.is_a?(RDF::URI) and e.to_s.match(BASE_URI)
  }
  if not missing.empty?
    puts "Missing usage for subject(s):"
    missing.sort.each do |subject|
      rdf_type = g.query([subject, RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), nil]).first.object
      next if rdf_type == RDF::URI("https://w3id.org/jp-textbook/Textbook")
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
