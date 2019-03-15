require 'sinatra'
require 'sinatra/namespace'
require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: "mysql2", 
  host: 'localhost',
  database: 'development',
  username: 'root')

# Models
class Domain < ActiveRecord::Base
  self.inheritance_column = 'null_and_void'
  has_many :records, :dependent => :delete_all
end

class Record < ActiveRecord::Base
  self.inheritance_column = 'null_and_void'
  belongs_to :domain
end

# Serializers
class DomainSerializer
  def initialize(domain)
    @domain = domain
  end

  def as_json(*)
      data = {
        id: @domain.id.to_s,
        name: @domain.name,
        records: @domain.records.size
      }
    data[:errors] = @doamin.errors if @domain.errors.any?
    data
  end
end

class RecordSerializer
  def initialize(record)
    @record = record
  end

  def as_json(*)
    data = {
      domain_id: @record.domain_id.to_s,
      id: @record.id.to_s,
      name: @record.name,
      type: @record.type,
      content: @record.content,
      ttl: @record.ttl.to_s
    }
    data[:errors] = @record.errors if @record.errors.any?
    data
  end
end

get '/' do
  'Welcome to BookList!'
end

namespace '/api/v1' do
  before do
    content_type 'application/json'
  end

  helpers do
    def base_url
      @base_url ||= "#"
      "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
    end

    def json_params
      begin
        JSON.parse(request.body.read)
      rescue
        halt 400, { message:'Invalid JSON' }.to_json
      end
    end
  end

  # domains
  get '/domains' do
    domains = Domain.all
    domains.map { |domain| DomainSerializer.new(domain) }.to_json
  end

  get '/domains/:id' do |id|
    domain = Domain.where(id: id).first
    halt(404, { message: 'Domain Not Found'}.to_json) unless domain
    DomainSerializer.new(domain).to_json
  end

  post '/domains' do
    domain = Domain.new(json_params)
    if domain.save
      response.headers['Location'] = "#{base_url}/api/v1/domains/#{domain.id}"
      status 201
    else
      status 422
      body DomainSerializer.new(domain).to_json
    end
  end

  delete '/domains/:id' do |id|
    domain = Domain.where(id: id).first
    domain.destroy if domain
    status 204
  end

  # records
  get '/domains/:id/records' do |id|
    domain = Domain.where(id: id).first
    halt(404, { message: 'Domain Not Found'}.to_json) unless domain
    records = domain.records
    records.map { |record| RecordSerializer.new(record) }.to_json
  end

  post '/domains/:id/records' do |id|
    domain = Domain.where(id: id).first
    record = domain.records.new(json_params)

    halt(404, { message: 'Domain Not Found'}.to_json) unless domain
    if record.save
      response.headers['Location'] = "#{base_url}/api/v1/domains/#{domain.id}/records/#{record.id}"
      status 201
    else
      status 422
      body DomainSerializer.new(domain).to_json
    end
  end

  delete '/domains/:id/records/:record_id' do |id, record_id|
    record = Record.where(domain_id: id, id: record_id).first
    record.destroy if record
    status 204
  end
end
