#!/usr/bin/env ruby

require "nokogiri"
require "lisbn"

isbn = []

class BooksRdfParser < Nokogiri::XML::SAX::Document
  def initialize
    super
    @ncid = nil
    @isbn = []
    @results = {}
  end
  def start_element(name, attrs)
    if name == "rdf:Description"
      attrs.each do |attr_name, attr_val|
        if attr_name == "rdf:about" and attr_val =~ /ncid\/(\w+)#entity\z/
          @ncid = $1
        end
      end
    elsif name == "dcterms:hasPart"
      #<dcterms:hasPart rdf:resource="urn:isbn:9784889241778"/>
      attrs.each do |attr_name, attr_val|
        if attr_name == "rdf:resource" and attr_val =~ /\Aurn:isbn:(\w+)\z/
          @isbn << $1
        end
      end
    end
  end
  def end_element(name)
    if name == "rdf:Description"
      @isbn.each do |isbn|
        isbn13 = Lisbn.new(isbn).isbn13
        puts [isbn13, @ncid].join("\t")
      end
      @ncid = nil
      @isbn = []
    end
  end
end

parser = Nokogiri::XML::SAX::Parser.new(BooksRdfParser.new)
STDERR.puts "loading books.rdf..."
parser.parse(open("books.rdf"))
