#!/usr/bin/env ruby

require "net/http"
require "uri"
require "json"
require "roo"
require "pp"

ENDPOINT = "https://dydra.com/masao/jp-cos/sparql"
SPARQL = <<EOF
PREFIX schema: <http://schema.org/>
PREFIX cs: <https://w3id.org/jp-cos/>
select * where { 
  cs:%s schema:hasPart+ ?child.
} ORDER BY ASC(?child)
EOF

class DataCache
  @@cache = {}
  def self.[]=(key, value)
    @@cache[key] = value
  end
  def self.[](key)
    @@cache[key]
  end
end
def expand_coscode_hier(coscodes)
  results = []
  return [] if coscodes.nil? or coscodes.empty?
  coscodes.strip.split(/,/).each do |coscode|
    results << "https://w3id.org/jp-cos/#{coscode}"
    if not DataCache[coscode]
      sparql = SPARQL % coscode
      uri = ENDPOINT + "?" + URI.encode_www_form(query: sparql)
      STDERR.puts uri
      body = Net::HTTP.get(URI.parse(uri))
      data = JSON.load(body)
      data["results"]["bindings"].each do |bindings|
        results << bindings["child"]["value"]
      end
      DataCache[coscode] = results
      sleep(0.3)
    else
      STDERR.puts "cache hit!"
      results << DataCache[coscode]
    end
  end
  results.flatten.sort.uniq
end

if $0 == __FILE__
  if ARGV.size < 1
    puts "USAGE #$0 filename [sheetname]"
    exit
  end
  xlsx = Roo::Spreadsheet.open(ARGV[0])
  skip = true
  cos_idx = nil
  xlsx.each_row_streaming(pad_cels: true) do |row|
    if skip
      if row[0].to_s == "No"
        skip = false
        cos_idx = row.index{|e| e.to_s == "cosコード" }
      end
      next
    end
    next if row.empty? or row[0].empty?
    coscode = row.find(""){|e| e.coordinate[1] == cos_idx + 1 }.to_s
    if coscode and not coscode.empty?
      expanded = expand_coscode_hier(coscode).join(",")
      puts [ row[0], coscode, expanded ].join("\t")
    else
      puts row[0]
    end
  end
end
