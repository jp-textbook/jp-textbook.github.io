#!/usr/bin/env ruby

require "ttl2html"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  data = {}
  ttl2html = TTL2HTML::App.new
  ["all-textbook.ttl", "all-teachingUnit.ttl"].each do |filename|
    ttl_filename = find_turtle(filename)
    data = ttl2html.load_turtle(ttl_filename)
  end
  subjects = []
  objects = []
  predicates = []
  data.each do |k, v|
    subjects << k
    v.each do |p, o|
      predicates << p
      objects.concat(o)
    end
  end
  missing = ( subjects - objects - predicates ).select do |e|
    e.to_s =~ /\Ahttps?:\/\// and e.start_with?(BASE_URI)
  end.uniq
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
  missing = ( objects - subjects ).select{|e|
    e.to_s =~ /\Ahttps?:\/\// and e.to_s.start_with?(BASE_URI)
  }.uniq
  if not missing.empty?
    puts "Missing definition for object(s):"
    missing.sort.each do |object|
      p object
    end
  end
  missing = ( predicates - subjects ).select{|e|
    e.to_s =~ /\Ahttps?:\/\// and e.to_s.start_with?(BASE_URI)
  }.uniq
  if not missing.empty?
    puts "Missing definition for predicate(s):"
    missing.sort.each do |predicate|
      p predicate
    end
  end
end
