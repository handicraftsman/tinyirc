class TinyIRC::AppLogger
  class << self
    attr_accessor :log
  end

  @log = ParticleLog.new('web', ParticleLog::IO)
  @log.level_table[ParticleLog::IO] = 'REQ'

  def initialize(app)
    @app = app
  end

  def call(env)
    @start = Time.now
    @status, @headers, @body = @app.call(env)
    @duration = ((Time.now - @start).to_f * 1000).round(2)

    TinyIRC::AppLogger.log.io "#{env['REMOTE_ADDR']} --- #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} --- #{@duration} ms"

    [@status, @headers, @body]
  end
end

class TinyIRC::App < Sinatra::Application
  class << self
    attr_accessor :bot
  end

  use TinyIRC::AppLogger

  def self.cfg(bot)
    TinyIRC::App.bot = bot
    configure do
      disable :show_exceptions

      set :clean_trace, true

      set :public_folder, File.dirname(__FILE__) + '/public'
      set :views, File.dirname(__FILE__) + '/views'

      set :bind, ENV['HOST'] || '0.0.0.0'
      set :port, (ENV['PORT'] || 8080).to_i
    
      disable :logging
    end
  end

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  get '/' do
    @pagename = 'Groups'
    erb :index, layout: :layout
  end

  get '/favicon.ico' do 404 end

  get '/:plugin' do
    @pagename = params['plugin']
    @plugin = TinyIRC::App.bot.plugins[params['plugin']]
    raise RuntimeError, "Cannot find plugin `#{params['plugin']}`" unless @plugin
    erb :plugin, layout: :layout
  end

  error 404 do
    @page = '404'
    erb :'404', layout: :layout
  end

  error do
    @page = '500'
    erb :'500', layout: :layout
  end
end