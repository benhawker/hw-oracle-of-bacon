require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri

  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    if @from == @to
      self.errors.add(:from, 'cannot be the same as To')
    end
  end

  def initialize(api_key='')
    @from = 'Kevin Bacon'
    @to = 'Kevin Bacon'
    @api_key = api_key
    @uri = nil
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e

      raise NetworkError, e.message
    end
    @response = Response.new(xml)
  end

  def make_uri_from_arguments
    @uri = 'http://oracleofbacon.org/cgi-bin/xml?p='+CGI.escape(api_key)+'&a=' + CGI.escape(from) + '&b=' + CGI.escape(to)
  end

  class Response
    attr_reader :type, :data
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      elsif ! @doc.xpath('/other').empty?
        parse_unknown_response
      else
        parse_graph_response
      end
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end

    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('//match').map(&:text)
    end

    def parse_unknown_response
      @type = :unknown
      @data = 'Unknown response type'
    end

    def parse_graph_response
      @type = :graph
      actors = @doc.xpath('//actor')
      movies = @doc.xpath('//movie')
      @data = actors.zip(movies).flatten.compact.map(&:text)
    end

  end
end

