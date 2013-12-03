require 'sinatra'
require 'padrino-helpers'
require 'log4r'
require 'compass'
require 'sprockets'
require 'sprockets-helpers'
require 'sprockets-sass'
require 'bootstrap-sass'

# Setup logging
log = Log4r::Logger.new('Steno')
log.add Log4r::StderrOutputter.new('stderr')
log.outputters.last.formatter = Log4r::PatternFormatter.new(pattern: '%d %c %m')

$:.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'steno/document'
require 'steno/document_parser'

class StenoApp < Sinatra::Base
  set :root,          File.dirname(__FILE__)
  set :sprockets,     Sprockets::Environment.new(root)
  set :precompile,    [ /\w+\.(?!js|css).+/, /app.(css|js)$/ ]
  set :assets_prefix, '/assets'
  set :digest_assets, false

  set :haml,          format: :html5
  disable :protect_from_csrf
  enable :logging

  register Padrino::Helpers

  configure do
    # Setup Sprockets
    %w{javascripts stylesheets images}.each do |type|
      sprockets.append_path File.join(root, 'assets', type)
      sprockets.append_path Compass::Frameworks['bootstrap'].templates_directory + "/../vendor/assets/#{type}"
    end
 
    # Configure Sprockets::Helpers (if necessary)
    Sprockets::Helpers.configure do |config|
      config.environment = sprockets
      config.prefix      = assets_prefix
      config.digest      = digest_assets
      config.public_path = public_folder
      config.debug       = true if development?
    end
  end

  helpers do
    include Sprockets::Helpers
  end

  get "/" do
    haml :index
  end

  post "/parse" do
    parser = Steno::DocumentParser.new
    parser.metadata = Steno::Metadata.new(params[:doc][:meta])
    parser.options = {
      section_number_after_title: params[:doc][:options][:section_number_after_title].present?
    }

    doc = parser.parse(params[:doc][:source_text])

    content_type "application/json"
    {
      "source_text" => parser.source_text,
      "parse_errors" => parser.parse_errors,
      "xml" => doc ? doc.xml : nil,
    }.to_json
  end

  post "/render" do
    doc = Steno::Document.new
    doc.xml = (params[:doc] || {})[:xml]

    content_type "application/json"
    {
      "html" => doc.render,
      "toc"  => doc.render_toc
    }.to_json
  end

  post "/validate" do
    doc = Steno::Document.new
    doc.xml = params[:doc][:xml]

    doc.validate!

    content_type "application/json"
    {
      "validation_errors" => doc.validation_errors,
      "validates" => doc.validates?
    }.to_json
  end
end
