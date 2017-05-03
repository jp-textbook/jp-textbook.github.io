#!/usr/bin/env ruby

require "csv"
require "nkf"

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
@prefix nier:      <http://dl.nier.go.jp/library/vocab/>.
@prefix textbook:  <https://w3id.org/jp-textbook/>.
EOF

def compare_ignorespaces(str1, str2)  # 氏名等を空白を無視して比較する
  str1.to_s.gsub(/[\s,]+/, "") == str2.to_s.gsub(/[\s,]+/, "")
end

def format_pvalue(value)
  if value =~ /\Ahttps?:\/\//
    %Q|<#{value}>|
  else
    %Q|"#{value}"|
  end
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
  grade = row["学年"].to_s.gsub(/　/, "")
  data = {
    "schema:name" => row["書名"],
    "schema:editor" => row["編著者"],
    "schema:publisher" => row["発行者"],
    "schema:bookEdition" => row["版"],
    "nier:callNumber" => row["請求記号"],
    "nier:recordID" => row["書誌ID"],
    "textbook:catalogue" => "#{BASE_URI}/catalogue/#{row["学校種別"]}/#{row["★教科書目録掲載年度"]}",
    "textbook:school" => "http://ja.dbpedia.org/resource/#{row["学校種別"]}",
    "textbook:subjectArea" => "#{curriculum}/#{subject_area}",
    "textbook:subject" => "#{curriculum}/#{subject_area}/#{subject}",
    "textbook:grade" => grade,
    "textbook:curriculum" => "#{curriculum}",
    "textbook:authorizedYear" => row["検定年(西暦)"],
    "textbook:usageYear" => row["使用年度(西暦)"],
    "textbook:textbookSymbol" => row["教科書記号"],
    "textbook:textbookNumber" => row["教科書番号"],
  }
  if done[uri]
    STDERR.puts "WARN: #{uri} duplicates! [#{done[uri]["nier:recordID"]}/#{data["nier:recordID"]}] (#{done[uri]["textbook:usageYear"]} vs #{data["textbook:usageYear"]})"
    if done[uri]["textbook:usageYear"] > data["textbook:usageYear"]
      tmp = done[uri].dup
      done[uri] = data.dup
      data = tmp
    end
    prev_years = done[uri]["textbook:usageYear"].split(/\D+/).map{|i| i.to_i }
    next_years = data["textbook:usageYear"].split(/\D+/).map{|i| i.to_i }
    #if prev_years[-1] == next_years[0] or prev_years[-1] = next_years[0]-1
    #  done[uri]["textbook:usageYear"] = "#{prev_years[0]}-#{next_years[-1]}"
    #end
    done[uri]["textbook:usageYear"] << ", #{data["textbook:usageYear"]}"
    note = "#{next_years[0]}年度より"
    %w[ schema:publisher schema:name schema:editor schema:bookEdition
        textbook:school textbook:subjectArea textbook:subject textbook:grade textbook:curriculum
        textbook:authorizedYear textbook:textbookSymbol textbook:textbookNumber ].each do |property|
      if not compare_ignorespaces(done[uri][property], data[property])
        STDERR.puts "  #{property}: #{done[uri][property]} vs #{data[property]}" 
        note << %Q[#{PROPERTY_LABEL[property]}を「#{data[property]}」に変更。]
      end
    end
    %w[ textbook:catalogue nier:recordID nier:callNumber ].each do |property|
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
  %w[ schema:name schema:editor schema:publisher schema:bookEdition nier:callNumber nier:recordID
      textbook:catalogue textbook:school textbook:subjectArea textbook:subject textbook:grade textbook:curriculum
      textbook:authorizedYear textbook:usageYear textbook:textbookSymbol textbook:textbookNumber textbook:note ].each do |property|
    if data[property] and not data[property].empty?
      str << format_property(property, data[property])
    end
  end
  print str.join(";\n")
  puts "."
end
