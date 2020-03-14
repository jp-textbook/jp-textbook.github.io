#!/usr/bin/env ruby

require_relative "util.rb"

include Textbook

HEADERS = [
  "sh:path",
  "sh:name@ja", "sh:name@en",
  "sh:description@ja", "sh:description@en",
  "skos:example",
  "sh:maxCount", "sh:minCount",
  "sh:class", "sh:datatype",
  "sh:node", "sh:nodeKind",
  "sh:languageIn", "sh:uniqueLang",
]
#puts HEADERS.join("\t")

data = load_turtle "shape.ttl"
props = []
props_global = []
data.sort_by{|k,v| k }.each do |uri, v|
  #next if not uri =~ /^http/
  if v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"] and v["http://www.w3.org/1999/02/22-rdf-syntax-ns#type"].first == "http://www.w3.org/ns/shacl#NodeShape"
    puts
    #STDERR.puts [uri, v].inspect
    puts ([uri] + HEADERS).join("\t")
    target_class = v["http://www.w3.org/ns/shacl#targetClass"].first if v["http://www.w3.org/ns/shacl#targetClass"]
    puts [ "sh:targetClass", target_class ].join("\t")
    props = []
    if v["http://www.w3.org/ns/shacl#property"]
      v["http://www.w3.org/ns/shacl#property"].each do |p|
        #data[p].each do |prop, val|
        #  props << prop
        #end
        puts "sh:property\t"+HEADERS.map{|e|
          lang = nil
          e = e.to_s.sub(/\@(\w+)\Z/) do |m|
            lang = $1.intern
            ""
          end
          property_uri = e.sub("sh:", "http://www.w3.org/ns/shacl#").sub("skos:", "http://www.w3.org/2004/02/skos/core#")
          if data[p][property_uri].nil?
            ""
          elsif lang
            data[p][property_uri][lang]
          elsif data[p][property_uri].first =~ /^_:/
            parse_rdf_list(data[p][property_uri].first, data).join(" ")
          else
            data[p][property_uri].first
          end
        }.join("\t")
      end
    end
    if v["http://www.w3.org/ns/shacl#or"]
      v["http://www.w3.org/ns/shacl#or"].each do |p|
        #puts p.inspect
        v[p]
      end
    end
    props = props.flatten.sort.uniq.map do |e|
      e.sub("http://www.w3.org/ns/shacl#", "sh:").sub("http://www.w3.org/2004/02/skos/core#", "skos:")
    end
    #p props
    #p [uri, props]
    #props_global << props
  end
end
#p props_global.flatten.sort.uniq
