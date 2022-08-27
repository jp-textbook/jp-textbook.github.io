#!/usr/bin/env ruby

require "csv"
require "roo"
require "nkf"
require "logger"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  if ARGV.size < 1
    puts "USAGE: #$0 data.xls [sheet_name]"
    puts
    puts "   Note: default sheet_name is \"#{ SHEET_NAME }\""
    exit
  end

  logger = Logger.new(STDERR, level: :info)

  puts <<EOF
@prefix bf:        <http://id.loc.gov/ontologies/bibframe/>.
@prefix schema:    <http://schema.org/>.
@prefix textbook:  <https://w3id.org/jp-textbook/>.
@prefix textbook-rc:  <http://dl.nier.go.jp/library/vocab/textbook-rc/>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
EOF

  textbook_master = load_turtle("textbook.ttl")
  isbn_data = load_idlists #("IDList1_2.tsv", "IDList2_2.tsv") # cf. https://www.ndl.go.jp/jp/dlib/standards/opendataset/#ids
  logger.info("NDL data loaded: #{isbn_data.size}")
  isbn_ncid = load_books_rdf_tsv # cf. https://www.nii.ac.jp/CAT-ILL/about/infocat/od/
  logger.info("NCID data loaded: #{isbn_ncid.size}")

  done = {}
  xlsx = Roo::Excelx.new(ARGV[0])
  headers = xlsx.row(1)
  xlsx.each_row_streaming(offset: 1, pad_cells: true) do |x_row|
    row = map_xlsx_row_headers(x_row, headers)
    textbook_symbol = row["教科書記号"].normalize.gsub(/\d+/){|m| "I" * m.to_i }
    uri = "#{BASE_URI}#{row["学校種類"]}/#{row["検定済年･著作年西暦"]}/#{textbook_symbol}/#{row["教科書番号"]}"
    next if row["ISBN"].nil? or row["ISBN"].strip.empty?
    next if not textbook_master[uri]
    call_number = [
      row["当館分類番号1段目"].strip,
      row["当館分類番号2段目"].strip,
      row["当館分類番号3段目"].strip,
    ].join("|")
    data = {
      "textbook:item" => {
        "a" => "textbook:ItemTextbookRC",
        "textbook-rc:callNumber" => call_number,
        "textbook-rc:recordID" => row["目録レコード番号"]
      },
      "schema:isbn" => row["ISBN"].strip,
    }
    done[uri] ||= []
    done[uri] << data
  end

  done.sort_by{|k,v| k }.each do |uri, array|
    str = []
    array.each do |data|
      %w[ textbook:item schema:isbn ].each do |property|
        if data[property] and not data[property].empty?
          str << format_property(property, data[property])
        end
      end
      if data["schema:isbn"] and not data["schema:isbn"].empty?
        isbn = Lisbn.new(data["schema:isbn"])
        if isbn_data[isbn.isbn13]
          isbn_data[isbn.isbn13][:jpno].each do |jpno|
            str << format_property("rdfs:seeAlso", "http://id.ndl.go.jp/jpno/#{jpno}")
          end
          isbn_data[isbn.isbn13][:ndlbib].each do |ndlbib|
            str << format_property("rdfs:seeAlso", "http://id.ndl.go.jp/bib/#{ndlbib}")
          end
          isbn_data[isbn.isbn13][:pid].each do |pid|
            str << format_property("rdfs:seeAlso", "http://dl.ndl.go.jp/#{pid}")
          end
        end
        if isbn_ncid[isbn.isbn13]
          isbn_ncid[isbn.isbn13].each do |ncid|
            str << format_property("rdfs:seeAlso", "https://ci.nii.ac.jp/ncid/#{ncid}")
          end
        end
      end
    end
    puts "<#{uri}>"
    print str.join(";\n")
    puts "."
  end
end
