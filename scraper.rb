#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraperwiki'
require 'wikidata/fetcher'

module Wikisnakker
  class Area < Item
    SKIP = %i(P17 P18 P242 P910).to_set
    # TODO, reinstate this once Wikisnakker handles co-ordinates
    SKIP << :P625

    WANT = {
      P31:  :type,
      P571: :start_date,
      P576: :end_date,
    }.freeze

    def data
      unknown_properties.each do |p|
        warn "Unknown property for #{id}: #{p} = #{send(p).value}"
      end

      base_data.merge(wanted_data).merge(names)
    end

    private

    def base_data
      { id: id }
    end

    def names
      labels.map { |k, v| ["name__#{k.to_s.gsub('-','_')}", v[:value]] }.to_h
    end

    def unknown_properties
      properties.reject { |p| SKIP.include?(p) || WANT.key?(p) }
    end

    def wanted_properties
      properties.select { |p| WANT.key?(p) }
    end

    def wanted_data
      wanted_properties.map { |p| [WANT[p], send(p).value.to_s] }.to_h
    end
  end
end

module Wikidata
  require 'wikisnakker'

  class Areas
    def initialize(ids:)
      @ids = ids
    end

    def areas
      wikisnakker_items.flat_map(&:data).compact
    end

    private

    attr_reader :ids

    def wikisnakker_items
      @wsitems ||= Wikisnakker::Area.find(ids)
    end
  end
end

query = <<QUERY
  SELECT DISTINCT ?item
  WHERE
  {
    ?item wdt:P31 wd:Q28007428 .
  }
QUERY

wanted = EveryPolitician::Wikidata.sparql(query % 27)
raise 'No ids' if wanted.empty?

data = Wikidata::Areas.new(ids: wanted).areas
ScraperWiki.save_sqlite(%i(id), data)
