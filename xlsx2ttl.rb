#!/usr/bin/env ruby

require "csv"
require "roo"
require "logger"
require_relative "util.rb"

if $0 == __FILE__
  include Textbook
if ARGV.size < 1
  puts "USAGE: #$0 data.xlsx"
  exit
end

logger = Logger.new(STDERR, level: :info)

puts <<EOF
@prefix schema:    <http://schema.org/>.
@prefix bf:        <http://id.loc.gov/ontologies/bibframe/>.
@prefix nier:      <http://dl.nier.go.jp/library/vocab/>.
@prefix textbook:  <https://w3id.org/jp-textbook/>.
@prefix xsd:       <http://www.w3.org/2001/XMLSchema#>.
EOF

done = {}
c = load_turtle("curriculum.ttl")
subject_data = load_turtle("subject.ttl")
publisher_data = load_turtle("publisher.ttl")
fix_curriculums = c.keys.select do |k| # cf. #59
  if c[k]["https://w3id.org/jp-textbook/school"].first == "http://ja.dbpedia.org/resource/高等学校" or
     c[k]["https://w3id.org/jp-textbook/school"].first == "https://w3id.org/jp-textbook/school/高等学校"
    case c[k]["http://schema.org/startDate"].first
    when "1994-04-01", "2003-04-01", "2013-04-01"
      true
    else
      false
    end
  end
end

tempfile = "/tmp/temp-#{$$}.txt"
io = File.open(tempfile, "w")
xlsx = Roo::Excelx.new(ARGV[0])
xlsx.each_row_streaming(pad_cells: true) do |row|
  io.puts row.map{|e|
    e.to_s.gsub(/[\t\"]/, "")
  }.join("\t")
end
xlsx.close
io.close

CSV.foreach(tempfile, col_sep: "\t", headers: true) do |row|
  next if row["状態区分名称"] == "取り下げ"
  uri = "#{BASE_URI}#{row["/SCLASS#1"]}/#{row["/ADATE#1"]}/#{row["/TXSIGN#1"]}/#{row["/TXC#1"]}"
  curriculum = row["学習指導URI"]
  next if not curriculum =~ %r|https://w3id.org/jp-textbook/curriculum/.+|
  subject_area = row["/SUBJECT#1"]
  subject = row["/ITEM#1"].to_s
  p row["メタデータID"] if subject.nil?
  subject = subject.normalize.gsub(/\s+/, "").gsub(/1/, "I").gsub(/2/, "II").gsub(/3/, "III")
  school = row["/SCLASS#1"]
  grades = []
  (1..6).each do |i|
    grade = row["/GRADE##{i}"]
    if grade.to_i > 0
      grades << grade.to_i
    elsif grade.nil?
      #skip
    else
      logger.warn "Grade #{row["/GRADE##{i}"].inspect} not supported: #{uri}"
    end
  end
  pages = row["/PAGE#1"].to_s.strip
  unless pages.empty?
    pages = pages.split(/\s*;\s*/)
    if /\A\d+\Z/ =~ pages[0]
      extent, dimensions = pages
    else
      dimensions, extent = pages
    end
  end
  catalogues = []
  usage_year_start = row["/SDATE#1"].to_i
  usage_year_start = nil if usage_year_start == 0
  usage_year_end   = row["/EDATE#1"].to_i
  usage_year_end = nil if usage_year_end == 9999
  usage_years = if usage_year_start
                  (usage_year_start .. (usage_year_end or CURRENT_YEAR))
                else
                  []
                end
  usage_year_str = if usage_year_start.nil?
                     nil
                   elsif usage_year_end.nil?
                     "#{usage_year_start}-"
                   elsif usage_years.size == 1
                     usage_year_start.to_s
                   else
                     [usage_year_start, usage_year_end].join("-")
                   end
  logger.warn "#{uri}: catalogue and usage year mismatch (#{row["/PDATE#1"]} vs #{row["/SDATE#1"]})" if usage_year_start and row["/PDATE#1"].to_i != usage_year_start-1
  logger.warn "#{uri}: usage year possible typo (#{row["/SDATE#1"]}-#{row["/EDATE#1"]})" if usage_year_start and usage_year_end and usage_year_start > usage_year_end
  data = {
    "schema:name" => row["/TITLE#1"],
    "schema:editor" => row["/CREATOR#1"],
    "schema:publisher" => usage_year_start.nil? ? nil : "#{BASE_URI}publisher/#{usage_year_start-1}/#{row["/PUA#1"]}",
    "schema:bookEdition" => row["/EDITION#1"],
    "textbook:item" => {
      "a" => "bf:Item",
      "nier:callNumber" => row["/CALLN#1"],
      "nier:recordID" => row["メタデータID"],
    },
    "textbook:catalogue" => usage_years.map{|y| "#{BASE_URI}catalogue/#{row["/SCLASS#1"]}/#{y-1}" },
    "textbook:school" => "#{BASE_URI}school/#{school}",
    "textbook:subjectArea" => "#{curriculum}/#{subject_area}",
    "textbook:subject" => "#{curriculum}/#{subject_area}/#{subject}",
    "textbook:grade" => grades,
    "textbook:curriculum" => "#{curriculum}",
    "textbook:authorizedYear" => "#{row["/ADATE#1"]}^^xsd:date",
    "textbook:usageYearRange" => usage_year_str,
    "textbook:usageYear" => usage_years.to_a.map{|e| "#{e}^^xsd:date" },
    "textbook:textbookSymbol" => row["/TXSIGN#1"],
    "textbook:textbookNumber" => row["/TXC#1"],
    "bf:extent" => extent,
    "bf:dimensions" => dimensions,
    "bf:note" => [],
  }
  data.delete("textbook:subject") if subject.empty?
  data["bf:note"] << row["/NOTE#1"] if row["/NOTE#1"]
  if subject == subject_area and fix_curriculums.include?( curriculum )
    if subject_area != "保健体育"
      data.delete("textbook:subject")
      logger.debug "REMOVE subject: "+ [uri, subject, subject_area].inspect
    end
  end
  if not data.has_key? "textbook:subject"
    subject_candidates = subject_data[data["textbook:subjectArea"]]["https://w3id.org/jp-textbook/hasSubject"].sort_by{|e| -(e.size) }
    if %w(情報 家庭 外国語).include? subject_area
      subject_candidates += subject_data[data["textbook:subjectArea"]+"(専門)"]["https://w3id.org/jp-textbook/hasSubject"]
      subject_candidates = subject_candidates.sort_by{|e| -(e.size) }
    end
    subject = subject_candidates.find{|e|
      data["schema:name"].normalize.include? e.last_part
    }
    if subject
      data["textbook:subject"] = subject
      data["textbook:subjectArea"] = subject.sub(/\/[^\/]+\z/, "")
    elsif %w(https://w3id.org/jp-textbook/高等学校/1995/商業/570 https://w3id.org/jp-textbook/高等学校/1995/商業/565 https://w3id.org/jp-textbook/高等学校/1999/商業/617 ).include? uri
      #adhoc. cf. #390
      data["textbook:subject"] = "#{curriculum}/#{subject_area}/経営情報"
    else
      logger.warn "Subject not found in titles: #{uri} (#{data["schema:name"].normalize} :: #{subject_area})"
    end
  end
  %w[ textbook:usageYearRange textbook:authorizedYear ].each do |year|
    if data[year] and data[year].split(/\D+/).find{|i| i.to_i > Date.today.year }
      #logger.warn "Year (#{year}=#{ data["textbook:usageYear"]}) is greater than today. cf. <#{uri}>"
    end
  end
  if done[uri]
    done_items = done[uri]["textbook:item"]
    record_ids = done_items.respond_to?(:key?) ? done_items["nier:recordID"] : done_items.map{|e| e["nier:recordID"] }.join(",")
    logger.warn "#{uri} duplicates! [#{record_ids}/#{data["textbook:item"]["nier:recordID"]}] (#{done[uri]["textbook:usageYear"]} vs #{data["textbook:usageYear"]})"
    if done[uri]["textbook:usageYearRange"] > data["textbook:usageYearRange"]
      tmp = done[uri].dup
      done[uri] = data.dup
      data = tmp
    end
    prev_years = done[uri]["textbook:usageYearRange"].split(/\D+/).map{|i| i.to_i }
    next_years = data["textbook:usageYearRange"].split(/\D+/).map{|i| i.to_i }
    done[uri]["textbook:usageYearRange"] << ", #{data["textbook:usageYearRange"]}"
    done[uri]["textbook:usageYear"] += data["textbook:usageYear"]
    note = "#{next_years[0]}年度より"
    %w[ schema:publisher schema:name schema:editor schema:bookEdition
        textbook:school textbook:subjectArea textbook:subject textbook:grade textbook:curriculum
        textbook:authorizedYear textbook:textbookSymbol textbook:textbookNumber
    ].each do |property|
      if not compare_ignorespaces(done[uri][property], data[property])
        logger.warn "  #{property}: #{done[uri][property]} vs #{data[property]}" 
        value = data[property]
        if property == "schema:publisher"
          tmp_value = data[property]
          tmp_value = data[property].first if data[property].is_a?(Array)
          value = publisher_data[tmp_value]["http://schema.org/name"][:ja]
        end
        note << %Q[#{PROPERTY_LABEL[property]}を「#{value}」に変更。]
      end
    end
    %w[ textbook:catalogue textbook:item bf:note schema:publisher ].each do |property|
      done[uri][property] = [ done[uri][property] ]
      done[uri][property] << data[property]
      done[uri][property].flatten!
      done[uri][property].uniq!
    end
    done[uri]["bf:note"] << note
    done[uri]["bf:note"].flatten!
    done[uri]["bf:note"].uniq!
  else
    done[uri] = data
  end
end

done.sort_by{|k,v| k }.each do |uri, data|
  str = [ "<#{uri}> a textbook:Textbook" ]
  %w[ schema:name schema:editor schema:publisher schema:bookEdition textbook:item
      textbook:catalogue textbook:school textbook:subjectArea textbook:subject textbook:grade textbook:curriculum
      textbook:authorizedYear textbook:usageYear textbook:usageYearRange
      bf:extent bf:dimensions
      textbook:textbookSymbol textbook:textbookNumber 
      bf:note
  ].each do |property|
    if data[property] and not data[property].empty?
      str << format_property(property, data[property])
    end
  end
  print str.join(";\n")
  puts "."
end

end
