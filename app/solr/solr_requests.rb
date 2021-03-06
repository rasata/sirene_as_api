require 'net/http'
require 'uri'

class SolrRequests < SireneAsAPIInteractor
  attr_accessor :keyword

  def initialize *keywords
    keyword = keywords[0].to_s.gsub(/[+<>'"=&,;\n]/, ' ') # Get first word in params & Prevent Solr injections
    keyword.upcase! # Need to upcase request since LowerCaseFilterFactory doens't work on FST implementation for some reason
    @keyword = CGI.unescape(keyword)
  end

  def get_suggestions
    http_session = Net::HTTP.new('localhost', solr_port)
    solr_response = http_session.get(uri_solr)
    return nil unless solr_response.is_a? Net::HTTPSuccess
    begin
      extract_suggestions(solr_response.body)
    rescue StandardError => error
      stdout_error_log "Suggestions not working correctly. Cause: #{error}. \n Solr response: #{solr_response.body}"
    end
  end

  def build_dictionary
    stdout_info_log 'Building suggester dictionary... This might take a while (~3 hours)'
    begin
      request_build_dictionary
    rescue StandardError => error
      stdout_error_log "Error while building dictionary : #{error}"
    else
      stdout_success_log('Dictionary was correctly built !')
    end
  end

  private

  def uri_solr
    "/solr/#{Rails.env}/suggesthandler?wt=json&suggest.q=#{@keyword}"
  end

  def extract_suggestions(solr_response_body)
    suggestions = []
    solr_response_hash = JSON.parse(solr_response_body)

    solr_response_hash['suggest']['suggest'][@keyword]['suggestions'].each do |hash|
      suggestions << hash['term']
    end
    return nil if suggestions.empty?
    suggestions
  end

  def request_build_dictionary
    http_session = Net::HTTP.new('localhost', solr_port)
    http_session.read_timeout = 14_400 # 4 hours max to build dictionary
    uri = "/solr/#{Rails.env}/suggesthandler?suggest.build=true"
    http_session.get(uri)
  end

  def solr_port
    sunspot_config = YAML.load_file('config/sunspot.yml')
    sunspot_config[Rails.env]['solr']['port']
  end
end
