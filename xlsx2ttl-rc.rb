#!/usr/bin/env ruby

require "csv"
require "roo"
require "nkf"
require "logger"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  SHEET_NAME = "教科書研究センターデータ"
  if ARGV.size < 1
    puts "USAGE: #$0 data.xls [sheet_name]"
    puts
    puts "   Note: default sheet_name is \"#{ SHEET_NAME }\""
    exit
  end

  logger = Logger.new(STDERR, level: :info)

  puts <<EOF
@prefix schema:    <http://schema.org/>.
@prefix textbook:  <https://w3id.org/jp-textbook/>.
@prefix textbook-rc:  <http://dl.nier.go.jp/library/vocab/textbook-rc/>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
EOF

  textbook_master = load_turtle("textbook.ttl")
  isbn_data = load_idlists("IDLists_1_2.tsv", "IDLists_2_2.tsv")
  isbn_ncid = load_books_rdf("books.rdf")

  done = {}
  xlsx = Roo::Excelx.new(ARGV[0])
  xlsx.default_sheet = SHEET_NAME
  headers = xlsx.row(1)
  xlsx.each_row_streaming(offset: 1, pad_cells: true) do |x_row|
    row = map_xlsx_row_headers(x_row, headers)
    #uri = [BASE_URI, row["学校種別"], row["検定年(西暦)"], row["教科書記号"], row["教科書番号"]].join("/")
    uri = row["教科書リソースURI_ttl作成用"]
    next if row["フラグ_ttl作成用（「NIERレコードなし」以外をttlに）"] =~ /\ANIERレコードなし/
    logger.warn("#{uri} is missing in the master data.") if not textbook_master[uri]
    call_number = [
      row["当館分類番号1段目"].strip,
      row["当館分類番号2段目"].strip,
      row["当館分類番号3段目"].strip,
    ].join("|")
    data = {
      "textbook:item" => {
        "textbook-rc:callNumber" => call_number,
        "textbook-rc:recordID" => row["目録レコード番号_ttl作成用"]
      },
      "schema:isbn" => row["ISBN_ttl作成用"].strip,
    }
    done[uri] ||= []
    done[uri] << data
  end

  done.sort_by{|k,v| k }.each do |uri, array|
    str = [ "<#{uri}> a textbook:Textbook" ]
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
            str << format_property("rdfs:seeAlso", "http://iss.ndl.go.jp/books/R100000002-I#{ndlbib}-00")
          end
          isbn_data[isbn.isbn13][:pid].each do |pid|
            str << format_property("rdfs:seeAlso", "http://dl.ndl.go.jp/#{pid}")
          end
        end
        if isbn_ncid[isbn.isbn13]
          str << format_property("rdfs:seeAlso", "https://ci.nii.ac.jp/ncid/#{isbn_ncid[isbn.isbn13]}")
        end
      end
    end
    print str.join(";\n")
    puts "."
  end
end
