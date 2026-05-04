#!/usr/bin/env ruby

require "csv"
require "roo"
require "nkf"
require "logger"
require "getoptlong"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
  SHEET_NAME_DEFAULT = "教科書研究センターデータ"
  BASE_URI = "https://w3id.org/jp-textbook"
  sheet_name = nil
  skip_load_isbn = false
  opts = GetoptLong.new(
    [ "--sheet", "-s", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--skip-load-isbn", GetoptLong::NO_ARGUMENT ],
  )
  opts.each do |opt, arg|
    case opt
    when "--sheet", "-s"
      sheet_name = arg
    when "--skip-load-isbn"
      skip_load_isbn = true
    end
  end

  if ARGV.size < 1
    puts "USAGE: #$0 [--skip-load-isbn] data.xls [sheet_name]"
    puts
    puts "   Note: default sheet_name is \"#{ SHEET_NAME_DEFAULT }\""
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
  isbn_data = {}
  isbn_data = load_idlists if not skip_load_isbn #("IDList1_2.tsv", "IDList2_2.tsv") # cf. https://www.ndl.go.jp/jp/dlib/standards/opendataset/#ids
  logger.info("NDL data loaded: #{isbn_data.size}")
  isbn_ncid = {}
  isbn_ncid = load_books_rdf if not skip_load_isbn # ("books.rdf.gz") # cf. https://www.nii.ac.jp/CAT-ILL/about/infocat/od/
  logger.info("NCID data loaded: #{isbn_ncid.size}")

  done = {}
  xlsx = Roo::Excelx.new(ARGV[0])
  #p xlsx.sheets
  xlsx.default_sheet = sheet_name if sheet_name and xlsx.sheets.include?(sheet_name)
  xlsx.default_sheet = SHEET_NAME_DEFAULT if not xlsx.default_sheet and xlsx.sheets.include?(SHEET_NAME_DEFAULT)
  headers = xlsx.row(1).map{|h| h.gsub(/\s+/, "") }
  xlsx.each_row_streaming(offset: 1, pad_cells: true) do |x_row|
    row = map_xlsx_row_headers(x_row, headers)
    uri = row["教科書リソースURI_ttl作成用"]
    next if row["フラグ_ttl作成用（「NIERレコードなし」以外をttlに）"] =~ /\ANIERレコードなし/
    next if row["学校種類"] == "特別支援学校"
    textbook_symbol = row["教科書記号"].normalize.strip
    textbook_symbol = case textbook_symbol
      when "C1"
        "CI"
      when "C2"
        "CII"
      when "C3"
        "CIII"
      else
        textbook_symbol
      end
    textbook_number = row["教科書番号"].normalize.strip
    uri = [BASE_URI, row["学校種類"], row["検定済年･著作年西暦"], textbook_symbol, textbook_number].join("/") if uri.nil?
    logger.warn("#{uri} is missing in the master data.") if not textbook_master.has_key?(uri)
    #p uri
    call_number = [
      row["当館分類番号1段目"].strip,
      row["当館分類番号2段目"].strip,
      row["当館分類番号3段目"].strip,
    ].join("|")
    data = {
      "textbook:item" => {
        "a" => "bf:Item",
        "textbook-rc:callNumber" => call_number,
        "textbook-rc:recordID" => row["目録レコード番号_ttl作成用"] || row["目録レコード番号"],
      },
      "schema:isbn" => row["ISBN_ttl作成用"]&.strip || row["ISBN"]&.strip,
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
          str << format_property("rdfs:seeAlso", "https://ci.nii.ac.jp/ncid/#{isbn_ncid[isbn.isbn13]}")
        end
      end
    end
    print "<#{uri}>\n"
    print str.join(";\n")
    puts "."
  end
end
