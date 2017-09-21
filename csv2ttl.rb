#!/usr/bin/env ruby

require "csv"
require "nkf"
require_relative "util.rb"

BASE_URI = "https://w3id.org/jp-textbook"
PROPERTY_LABEL = {
  "schema:name" => "書名", 
  "schema:editor" => "編著者", 
  "schema:publisher" => "出版社", 
  "schema:bookEdition" => "版",
  "textbook:grade" => "学年",
}

if ARGV.size < 1
  puts "USAGE: #$0 data.csv"
  exit
end

puts <<EOF
@prefix schema:    <http://schema.org/>.
@prefix bf:        <http://id.loc.gov/ontologies/bibframe/>.
@prefix nier:      <http://dl.nier.go.jp/library/vocab/>.
@prefix textbook:  <https://w3id.org/jp-textbook/>.
EOF

def compare_ignorespaces(str1, str2)  # 氏名等を空白を無視して比較する
  str1.to_s.gsub(/[\s,]+/, "") == str2.to_s.gsub(/[\s,]+/, "")
end

def format_pvalue(value)
  str = ""
  if value.is_a? Hash
    result = ["["]
    array = []
    value.keys.sort.each do |k|
      array << format_property(k, value[k])
    end
    result << array.join(";\n")
    result << "  ]"
    str = result.join("\n")
  elsif value =~ /\Ahttps?:\/\//
    str = %Q|<#{value}>|
  else
    str = %Q|"#{value}"|
  end
  str
end
def format_property(property, value)
  if value.is_a? Array
    value = value.map do |e| 
      format_pvalue(e)
    end
    %Q|  #{property} #{ value.join(", ") }|
  else
    value = format_pvalue(value)
    %Q|  #{property} #{value}|
  end
end

done = {}
c = load_turtle("curriculum.ttl")
fix_curriculums = c.keys.select do |k| # cf. #59
  if c[k]["https://w3id.org/jp-textbook/school"].first == "http://ja.dbpedia.org/resource/高等学校"
    case c[k]["http://schema.org/startDate"].first
    when "1994-04-01", "2003-04-01", "2013-04-01"
      true
    else
      false
    end
  end
end

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
  subject = subject.gsub(/1/, "I").gsub(/2/, "II").gsub(/3/, "III")
  school = row["学校種別"]
  grade = row["学年"].to_s.gsub(/　/, "").strip
  pages = row["ページ数・大きさ"].to_s.strip
  unless pages.empty?
    pages = pages.split(/\s*;\s*/)
    if /\A\d+\Z/ =~ pages[0]
      extent, dimensions = pages
    else
      dimensions, extent = pages
    end
  end
  data = {
    "schema:name" => row["書名"],
    "schema:editor" => row["編著者"],
    "schema:publisher" => row["発行者"],
    "schema:bookEdition" => row["版"],
    "textbook:item" => {
      "nier:callNumber" => row["請求記号"],
      "nier:recordID" => row["書誌ID"],
    },
    "textbook:catalogue" => "#{BASE_URI}/catalogue/#{row["学校種別"]}/#{row["★教科書目録掲載年度"]}",
    "textbook:school" => "http://ja.dbpedia.org/resource/#{school}",
    "textbook:subjectArea" => "#{curriculum}/#{subject_area}",
    "textbook:subject" => "#{curriculum}/#{subject_area}/#{subject}",
    "textbook:grade" => grade,
    "textbook:curriculum" => "#{curriculum}",
    "textbook:authorizedYear" => row["検定年(西暦)"],
    "textbook:usageYear" => row["使用年度(西暦)"],
    "textbook:textbookSymbol" => row["教科書記号"],
    "textbook:textbookNumber" => row["教科書番号"],
    "bf:extent" => extent,
    "bf:dimensions" => dimensions,
  }
  if subject == subject_area and fix_curriculums.include?( curriculum )
    if subject_area != "保健体育"
      data.delete("textbook:subject")
      STDERR.puts "REMOVE subject: "+ [uri, subject, subject_area].inspect
    end
  end
  if done[uri]
    STDERR.puts "WARN: #{uri} duplicates! [#{done[uri]["nier:recordID"]}/#{data["nier:recordID"]}] (#{done[uri]["textbook:usageYear"]} vs #{data["textbook:usageYear"]})"
    if done[uri]["textbook:usageYear"] > data["textbook:usageYear"]
      tmp = done[uri].dup
      done[uri] = data.dup
      data = tmp
    end
    prev_years = done[uri]["textbook:usageYear"].split(/\D+/).map{|i| i.to_i }
    next_years = data["textbook:usageYear"].split(/\D+/).map{|i| i.to_i }
    done[uri]["textbook:usageYear"] << ", #{data["textbook:usageYear"]}"
    note = "#{next_years[0]}年度より"
    %w[ schema:publisher schema:name schema:editor schema:bookEdition
        textbook:school textbook:subjectArea textbook:subject textbook:grade textbook:curriculum
        textbook:authorizedYear textbook:textbookSymbol textbook:textbookNumber
    ].each do |property|
      if not compare_ignorespaces(done[uri][property], data[property])
        STDERR.puts "  #{property}: #{done[uri][property]} vs #{data[property]}" 
        note << %Q[#{PROPERTY_LABEL[property]}を「#{data[property]}」に変更。]
      end
    end
    %w[ textbook:catalogue textbook:item ].each do |property|
      done[uri][property] = [ done[uri][property] ]
      done[uri][property] << data[property]
    end
    done[uri]["textbook:note"] = note
  else
    done[uri] = data
  end
end

done.sort_by{|k,v| k }.each do |uri, data|
  str = [ "<#{uri}> a schema:Book" ]
  %w[ schema:name schema:editor schema:publisher schema:bookEdition textbook:item
      textbook:catalogue textbook:school textbook:subjectArea textbook:subject textbook:grade textbook:curriculum
      textbook:authorizedYear textbook:usageYear
      bf:extent bf:dimensions
      textbook:textbookSymbol textbook:textbookNumber 
      textbook:note
  ].each do |property|
    if data[property] and not data[property].empty?
      str << format_property(property, data[property])
    end
  end
  print str.join(";\n")
  puts "."
end
