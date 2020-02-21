require 'sinatra'
require "sinatra/namespace"
require "sinatra/cors"
require "mongoid"

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,POST,PUT,DELETE,OPTIONS"
set :allow_headers, "content-type,if-modified-since"

# DB Setup
Mongoid.load! "mongoid.config"
class Action
  include Mongoid::Document

  field :name, type: String
  field :description, type: String
  field :completed, type: Boolean
  field :created, :type => DateTime, default: ->{ Date.today }

end

configure do
  set :bind, '0.0.0.0'
  enable :cross_origin
end

# Serializers
class ActionSerializer

  def initialize(action)
    @action = action
  end

  def as_json(*)
    data = {
      id: @action.id.to_s,
      name: @action.name,
      description: @action.description,
      completed: @action.completed,
      created: @action.created
    }
    data[:errors] = @action.errors if @action.errors.any?
    data
  end

end

# Endpoints

get '/' do
  'Actions list API'
end

namespace '/api/v1' do

  before do
    content_type 'application/json'
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  helpers do
    def base_url
      @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
    end

    def json_params
      begin
        JSON.parse(request.body.read)
      rescue
        halt 400, { message: 'Invalid JSON' }.to_json
      end
    end

    def action
      @action ||= Action.where(id: params[:id]).first
    end

    def halt_if_not_found!
      halt(404, { message: 'Action Not Found'}.to_json) unless action
    end

    def serialize(action)
      ActionSerializer.new(action).to_json
    end
  end

  get '/actions/' do
    actions = Action.all
    actions.map { |action| ActionSerializer.new(action) }.to_json
  end

  get '/actions/:id/' do |id|
    halt_if_not_found!
    serialize(action)
  end

  post '/actions/' do
    action = Action.new(json_params)
    halt 422, serialize(action) unless action.save
    response.headers['Location'] = "#{base_url}/api/v1/actions/#{action.id}"
    status 201
  end

  put '/actions/:id/' do |id|
    halt_if_not_found!
    halt 422, serialize(action) unless action.update_attributes(json_params)
    serialize(action)
  end

  delete '/actions/:id/' do |id|
    action.destroy if action
    status 204
  end

end
