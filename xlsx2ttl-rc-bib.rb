#!/usr/bin/env ruby

require "csv"
require "roo"
require "nkf"
require "logger"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook

  if ARGV.size != 1
    puts "USAGE: #$0 file.xlsx"
    exit
  end
  logger = Logger.new(STDERR, level: :info)

  puts <<EOF
@prefix schema: <http://schema.org/>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix textbook: <https://w3id.org/jp-textbook/>.
EOF

  textbook_master = load_turtle("textbook.ttl")
  textbook_rc_master = load_turtle("textbook-rc.ttl")
  isbn_data = load_idlists #("IDList1_2.tsv", "IDList2_2.tsv") # cf. https://www.ndl.go.jp/jp/dlib/standards/opendataset/#ids
  logger.info("NDL data loaded: #{isbn_data.size}")
  isbn_ncid = load_books_rdf_tsv # cf. https://www.nii.ac.jp/CAT-ILL/about/infocat/od/
  logger.info("NCID data loaded: #{isbn_ncid.size}")

  hash = {}
  xlsx = Roo::Excelx.new(ARGV[0])
  headers = xlsx.row(1)
  xlsx.each_row_streaming(offset: 1, pad_cells: true) do |x_row|
    data = {}
    row = map_xlsx_row_headers(x_row, headers)
    uri = "#{BASE_URI}#{row["学校種類"]}/#{row["検定済年･著作年西暦"]}/#{row["教科書記号"]}/#{row["教科書番号"]}"
    #p uri
    next if not textbook_master[uri]
    if ( textbook_rc_master[uri].nil? and not row["ISBN"].to_s.strip.empty? ) or ( textbook_rc_master[uri] and not textbook_rc_master[uri].has_key? "http://schema.org/isbn" and not row["ISBN"].to_s.strip.empty? )
      data["schema:isbn"] = Lisbn.new(row["ISBN"].strip).isbn13
    end
    isbn = row["ISBN"]
    isbn = textbook_rc_master[uri]["http://schema.org/isbn"].first if textbook_rc_master[uri] and textbook_rc_master[uri]["http://schema.org/isbn"]
    if isbn
      isbn13 = Lisbn.new(isbn).isbn13
      if isbn_data[isbn13]
        isbn_data[isbn13][:jpno].each do |jpno|
          jpno_uri = "http://id.ndl.go.jp/jpno/#{jpno}"
          next if textbook_rc_master[uri] and textbook_rc_master[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"] and textbook_rc_master[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"].include? jpno_uri
          data["rdfs:seeAlso"] ||= []
          data["rdfs:seeAlso"] << jpno_uri
        end
        isbn_data[isbn13][:ndlbib].each do |ndlbib|
          ndlbib_uri = "http://id.ndl.go.jp/bib/#{ndlbib}"
          next if textbook_rc_master[uri] and textbook_rc_master[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"] and textbook_rc_master[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"].include? ndlbib_uri
          data["rdfs:seeAlso"] ||= []
          data["rdfs:seeAlso"] = ndlbib_uri
        end
      end
      if isbn_ncid[isbn13]
        ncid_uri = "https://ci.nii.ac.jp/ncid/#{isbn_ncid[isbn13]}"
        if textbook_rc_master[uri] and textbook_rc_master[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"] and textbook_rc_master[uri]["http://www.w3.org/2000/01/rdf-schema#seeAlso"].include? ncid_uri
        else
          data["rdfs:seeAlso"] ||= []
          data["rdfs:seeAlso"] = ncid_uri
        end
      end
    end
    if not data.empty?
      hash[uri] ||= []
      hash[uri] << data
    end
  end

  hash.sort_by{|k,v| k }.each do |uri, array|
    str = []
    array.each do |data|
      data.keys.sort.each do |property|
          str << format_property(property, data[property])
      end
    end
    print "<#{uri}> #{str.join(";\n")}"
    puts "."
  end
end
