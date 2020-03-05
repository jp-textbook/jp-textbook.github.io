#!/usr/bin/env ruby

require "fileutils"
require 'ruby-progressbar'
require "rdf"
require "rdf/ntriples"
require "rdf/turtle"
require_relative "util.rb"

using ProgressBar::Refinements::Enumerator

def format(graph, subject, depth = 1)
  turtle = RDF::Turtle::Writer.new
  result = ""
  if subject.iri?
    result << "<#{subject}>\n#{"  "*depth}"
  else
    result << "[\n#{"  "*depth}"
  end
  result << graph.query([subject, nil, nil]).predicates.sort.map do |predicate|
    str = "<#{predicate}> "
    str << graph.query([subject, predicate, nil]).objects.sort_by do |object|
      if object.resource? and not object.iri? # blank node:
        graph.query([object, nil, nil]).statements.sort_by{|e|
          [ e.predicate, e.object ]
        }.map{|e|
          [ e.predicate, e.object ]
        }
      elsif object.literal?
        [ object, object.language ]
      else
        object
      end
    end.map do |object|
      if object.resource? and not object.iri? # blank node:
        format(graph, object, depth + 1)
      else
        case object
        when RDF::URI
          turtle.format_uri(object)
        else
          turtle.format_literal(object)
        end
      end
    end.join(", ")
    str
  end.join(";\n#{"  "*depth}")
  result << " ." if subject.iri?
  result << "\n"
  result << "#{"  "*(depth-1)}]" if not subject.iri?
  result
end

include Textbook
file = find_turtle("all.ttl")
STDERR.puts "loading #{file}..."
PREFIX = /\Ahttps:\/\/w3id.org\/jp-textbook\//
g = RDF::Graph.new
reader = RDF::Turtle::Reader.open(file) do |reader|
  g.insert_statements(reader.statements)
  g.subjects.each.with_progressbar(format: "%a %e %P% Processed: %c from %C") do |subject|
    uri = subject.to_s
    next if not uri =~ PREFIX
    file = uri.sub(PREFIX, "")
    file << ".ttl"
    dir = File.dirname(file)
    FileUtils.mkdir_p(dir) if not File.exist? dir
    str = format(g, subject)
    open(file, "w") do |io|
      io.puts str.strip
    end
  end
end
