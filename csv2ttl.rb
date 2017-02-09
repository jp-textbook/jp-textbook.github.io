#!/usr/bin/env ruby

# tsv2ttl.rb

require "csv"

BASE_URI = "https://w3id.org/jp-textbook"

CSV.foreach(ARGV[0], encoding: "CP932:utf-8", headers: true) do |row|
  #puts row.headers
  uri = [BASE_URI, row["学校種別"], row["検定年(西暦)"], row["教科書記号"], row["教科書番号"]].join("/")
  curriculum = [BASE_URI, row["学校種別"], row["検定年(西暦)"]] #TODO
  subject = row["種目"]
  subject = row["検索用種目"] if subject.empty?
  puts <<-EOF
<#{uri}> a schema:Book;
  schema:name "#{row["書名"]}";
  schema:editor "#{row["編著者"]}";
  schema:publisher "#{row["発行者"]}";
  nier:callNumber "#{row["請求記号"]}";
  nier:recordID "#{row["書誌ID"]}";
  textbook:recordedBy <#{BASE_URI}/catalogue/#{row["学校種別"]}/#{row["★教科書目録掲載年度"]}>;
  textbook:school <http://ja.dbpedia.org/resource/#{row["学校種別"]}>;
  textbook:subject <#{BASE_URI}/curriculum/#{row["学校種別"]}/#{row["検定年(西暦)"]}/#{subject}>;
  textbook:subjectArea <#{BASE_URI}/curriculum/#{row["学校種別"]}/#{row["検定年(西暦)"]}/#{subject}>;
  EOF
  unless row["学年"].strip.empty?
    puts %Q[  textbook:grade "#{row["学年"]}";]
  end
  puts <<-EOF
  textbook:curriculum <https://w3id.org/jp-textbook/curriculum/小学校/1992>;
  textbook:authorizedYear ""1991"";
  textbook:usageYear ""1992-1995"";
  textbook:textbookSymbol ""音楽"";
  textbook:textbookNumber ""101""."
  EOF
end
