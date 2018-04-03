class TinyIRC::Plugin
  attr_reader :commands, :event_handlers, :fullname, :groups, :loaded, :log, :name

  def initialize(bot, name)
    @loaded     = false
    
    @l_init     = lambda {}
    @l_postinit = lambda {}
    @l_config   = lambda {|cfg|}
    
    @bot      = bot
    @fullname = name
    @name     = File.basename(name)
    
    @commands       = {}
    @event_handlers = {}
    @groups         = {}

    @log = ParticleLog.new('?' + @name, ParticleLog::INFO) 
    @log.info 'Loading...'

    lp = "./#{name}.rb"
    ok = false
    if File.exists? lp
      instance_eval(File.read(lp), lp) 
      ok = true
    else
      $LOAD_PATH.each do |f|
        lp = File.join(f, name + '.rb')
        if File.exists? lp
          instance_eval(File.read(lp), lp)
          ok = true
        end
      end
    end

    raise RuntimeError, "Cannot find the `#{name}` plugin" unless ok

    _l_init
  end

  def init(&b) @l_init = b end
  def _l_init()
    @log.info 'Initializing...'
    @l_init.()
  end

  def postinit(&b) @l_postinit = b end
  def _l_postinit()
    @log.info 'Post-Initializing...'
    @l_postinit.()
    @loaded = true
    @log.important "Hello, bot!"
  end
    
  def configure(&b) @l_config = b end
  def _l_config(cfg)
    @log.info 'Configuring...'
    @l_config.(cfg)
  end

  def on(type, pattern, &block) 
    pattern[:type] = type
    pattern[:_block] = block
    @event_handlers[type] = pattern
  end

  def on(type, **pattern, &handler)
    @event_handlers[type] ||= []
    @event_handlers[type] << {
      pattern: pattern,
      handler: handler
    }
  end

  def cmd(name)
    @commands[name] = TinyIRC::Command.new(self, name)
    @commands[name]
  end

  def handle_command(h, cmd_info)
    return false if h[:cmd_info][:plugin] != @name && h[:cmd_info][:plugin] != :any
    x = if @commands.include? h[:cmd_info][:command]
      @commands[h[:cmd_info][:command]].handle_command(h, cmd_info)
    else
      false
    end
  end

  def group(name)
    n = "#{@name}/#{name}"
    @groups[n] = TinyIRC::Group.new n
    @groups[n]
  end
end