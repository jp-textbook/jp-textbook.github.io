#!/usr/bin/env ruby

require "csv"
require "nkf"

BASE_URI = "https://w3id.org/jp-textbook"

if ARGV.size < 1
  puts "USAGE: #$0 data.csv"
  exit
end

puts <<EOF
@prefix schema:    <http://schema.org/>.
@prefix nier:      <http://dl.nier.go.jp/library/vocab/>.
@prefix textbook:  <https://w3id.org/jp-textbook/>.
EOF

CSV.foreach(ARGV[0], encoding: "CP932:utf-8", headers: true) do |row|
  uri = [BASE_URI, row["学校種別"], row["検定年(西暦)"], row["教科書記号"], row["教科書番号"]].join("/")
  #curriculum = [BASE_URI, "curriculum", row["学校種別"], row["検定年(西暦)"]].join("/") #TODO
  curriculum = row["学習指導URI"]
  next if not curriculum =~ %r|https://w3id.org/jp-textbook/curriculum/.+|
  subject_area = row["教科"]
  subject_area = row["検索用教科"] if subject_area.nil? or subject_area.empty?
  subject = row["種目"]
  subject = row["検索用種目"] if subject.nil? or subject.empty?
  subject = NKF.nkf("-wZ1", subject).gsub(/\s+/, "")
  puts <<-EOF
<#{uri}> a schema:Book;
  schema:name "#{row["書名"]}";
  schema:editor "#{row["編著者"]}";
  schema:publisher "#{row["発行者"]}";
  nier:callNumber "#{row["請求記号"]}";
  nier:recordID "#{row["書誌ID"]}";
  textbook:catalogue <#{BASE_URI}/catalogue/#{row["学校種別"]}/#{row["★教科書目録掲載年度"]}>;
  textbook:school <http://ja.dbpedia.org/resource/#{row["学校種別"]}>;
  textbook:subjectArea <#{curriculum}/#{subject_area}>;
  textbook:subject <#{curriculum}/#{subject_area}/#{subject}>;
  EOF
  if row["学年"] and not row["学年"].strip.empty?
    puts %Q[  textbook:grade "#{row["学年"]}";]
  end
  puts <<-EOF
  textbook:curriculum <#{curriculum}>;
  textbook:authorizedYear "#{row["検定年(西暦)"]}";
  textbook:usageYear "#{row["使用年"]}";
  textbook:textbookSymbol "#{row["教科書記号"]}";
  textbook:textbookNumber "#{row["教科書番号"]}".
  EOF
end
