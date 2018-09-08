class TinyIRC::Bot
  class << self
    attr_accessor :log
  end

  attr_accessor(
    :config_file,
    :config,
    :sockets,
    :plugins,
    :groups,
    :prefix,
    :db,
    :config_mtx,
    :log
  )

  def initialize(config_file, db_file)
    @config_file = config_file
    
    @sockets = {}
    @plugins = {}
    @groups  = {}

    @log = ParticleLog.new 'bot', ParticleLog::INFO
    @log.important 'Hello, IRC!'
    
    @db = SQLite3::Database.open db_file
    @db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS groupinfo (
        server VARCHAR(32),
        host VARCHAR(64),
        name VARCHAR(32)
      );
    SQL
    @log.info "db = #{db_file}"

    @config_mtx = Mutex.new

    load_config
  end

  def load_config
    @config_mtx.synchronize do
      @config = YAML.parse_file(@config_file).to_ruby
      @prefix = @config['prefix'] || '!'
      @log.info "prefix = #{@prefix}"

      load_plugin_config
      load_group_config
      load_cooldown_config
      load_server_config
    end
  end

  def reload
    @config_mtx.synchronize do
      @plugins = {}
      @config = YAML.parse_file(@config_file).to_ruby
      @prefix = @config['prefix'] || '!'
      @log.info "prefix = #{@prefix}"

      load_plugin_config
      load_group_config
      load_cooldown_config
      load_server_config
    end
  end

  def load_plugin_config
    plugin_config = { "tinyirc/plugins/core" => nil }.merge(@config['plugins'] || {})

    def add(full, name)
      n = File.basename(name)
      if @plugins.include? n
        @log.error "Cannot have multiple plugins with same basename (#{n})"
      else
        @plugins[n] = TinyIRC::Plugin.new self, full
      end
    end

    def remove(name)
      @plugins.delete name
    end

    pkeys = {}
    plugin_config.keys.each do |k|
      pkeys[File.basename(k)] = k
    end
    
    (@plugins.keys - pkeys.keys).each do |k|
      @plugins[k].log.info 'Destroying...'
      remove k
    end

    (pkeys.keys - @plugins.keys).each do |k|
      add pkeys[k], k
    end

    @plugins.each_pair do |k, v|
      cfg = plugin_config[k] || {}
      raise RuntimeError, 'Invalid config type' if cfg.class != Hash
      v._l_config(cfg)
      unless v.loaded
        v._l_postinit
      end
    end
  end

  def load_group_config
    @groups = {}

    group_config = {
      "world" => {},
      "admin" => {}
    }.merge(@config['groups'] || {})

    def add_group(name, group_config)
      raise RuntimeError, 'User-defined group names cannot contain slashes!' if name.index '/'
      g = TinyIRC::Group.new name
      (group_config[name]['include'] || []).each do |g2|
        if g2.index '/'
          g2p, _ = *g2.split('/', 2)
          unless @plugins.include? g2p
            @log.error "There's no plugin called `#{g2p}`"
            next
          end
          unless @plugins[g2p].groups.include? g2
            @log.error "Plugin `#{g2p}` does not have group `#{g2}`"
            next
          end
          @plugins[g2p].groups[g2].perms.each do |perm|
            g.perm(perm.plugin, perm.command, perm.branch)
          end
        else
          unless @groups.include? g2
            @log.error "There's no group called `#{g2}`"
            next
          end
          @groups[g2].perms.each do |perm|
            g.perm(perm.plugin, perm.command, perm.branch)
          end
        end 
      end
      (group_config[name]['perms'] || []).each do |perm|
        g.perm *TinyIRC::Permission.parse(perm)
      end
      @groups[name] = g
    end

    def add(name, group_config)
      add_group(name, group_config)
    end

    def remove(name)
      @groups.delete name
    end

    (@groups.keys & group_config.keys).each do |k|
      add_group(k, group_config)
    end

    (@groups.keys - group_config.keys).each do |k|
      remove k
    end

    (group_config.keys - @groups.keys).each do |k|
      add(k, group_config)
    end
  end

  def load_cooldown_config
    cooldown_config = @config['cooldowns'] || {}

    l = ParticleLog.new('cooldowns', ParticleLog::INFO)

    cooldown_config.each_pair do |cmd, cld|
      cld = cld.to_i
      a = cmd.split('/', 3)
      if !a[0] || !a[1] && a[2]
        l.error "Invalid command entry: #{cld}"
        next
      end
      pname = a[0]
      command = a[1] || :all
      branch = a[2] || :all
      unless @plugins.include? pname
        l.error "There's no plugin called `#{pname}`"
        next
      end
      plugin = @plugins[pname]
      upd = lambda do |command|
        if branch == :all
          command.branches.each_pair do |_, b|
            b.cooldown = cld
            l.info "#{pname}/#{command.name}/#{b.id} <- #{cld}s"
          end
        else
          unless command.branches.include? branch
            l.error "`#{pname}/#{command.name}` command does not have branch called `#{branch}`"
            next
          end
          command.branches[branch].cooldown = cld
          l.info "#{pname}/#{command.name}/#{branch} <- #{cld}s"
        end
      end
      if command == :all
        plugin.commands.each_pair do |_, cmd|
          upd.(cmd)
        end
      else
        unless plugin.commands.include? command
          l.error "`#{pname}/#{command}` command does not have branch called `#{branch}`"
          next
        end
        upd.(plugin.commands[command])
      end
    end
  end

  def load_server_config
    server_config = @config['servers'] || {}

    def add(name, cfg)
      s = TinyIRC::IRCSocket.new(self, name, cfg)
      Thread.new { s.connect }
      @sockets[name] = s
    end

    def remove(name)
      @sockets[name].mtx.synchronize do
        @sockets.delete(name).disconnect
      end
    end

    (@sockets.keys & server_config.keys).each do |k|
      s = @sockets[k]
      c = server_config[k]
      Thread.new do
        #s.mtx.synchronize do
          should_restart = false
          should_restart = true if s.host != c['host']
          should_restart = true if s.port != c['port']
          should_restart = true if s.user != c['user']
          should_restart = true if s.rnam != c['rnam']

          s.disconnect if should_restart
          
          s.host = c['host']
          s.port = c['port']
          s.nick = c['nick']
          s.user = c['user']
          s.pass = c['pass']
          s.rnam = c['rnam']

          s.connect if should_restart
      end
    end

    (@sockets.keys - server_config.keys).each do |k|
      remove k
    end

    (server_config.keys - @sockets.keys).each do |k|
      add(k, server_config[k])
    end
  end

  def handle_command(h, cmd_info)
    @plugins.each_pair do |name, plugin|
      return true if plugin.handle_command(h, cmd_info)
    end
    false
  end

  def handle_event(e)
    TinyIRC.define_event_methods(e)
    Thread.new do
      @plugins['core'].handle_event(e)
    end
  end

  def start
    Thread.new do
      ioloop
    end

    TinyIRC::App.cfg self
    TinyIRC::App.run!
  end

  def ioloop
    def _read_line(socket)
      res = IO.select([socket.sock], nil, nil, 0.001)
      return nil unless res
      begin
        return socket.sock.readline("\r\n", chomp: true).force_encoding("UTF-8")
      rescue => e
        socket.log.error "#{e.class.name} - #{e.message}"
        socket.mtx.synchronize do
          socket.running = false
        end
        handle_event(type: :disconnect, socket: socket)
        return nil
      end
    end

    def read_line(socket)
      return unless socket.running
      msg = _read_line(socket)
      return unless msg
      socket.log.io "R> #{msg}"
      handle_event(type: :raw, raw_data: msg, socket: socket, bot: self)
    end

    def write_line(socket)
      return unless socket.running
      
      previous = socket.last_write
      current = Time.now
      diff = current - previous
      return if diff < 0.7 && diff > 0
      # todo - implement bursts

      msg = begin
        socket.queue.pop true
      rescue ThreadError
        nil
      end
      
      return unless msg
      begin
        socket.direct_write msg.force_encoding("UTF-8")
      rescue => e
        socket.log.error "#{e.class.name} - #{e.message}"
        socket.mtx.synchronize do
          socket.running = false
        end
        handle_event(type: :disconnect, socket: socket)
        return nil
      end

      socket.last_write = current
    end

    while true do
      sleep 0.001

      @sockets.each_pair do |sname, socket|
        sleep 0.001

        next unless socket.running

        read_line(socket)
        write_line(socket)
      end
    end
  end

  def inspect
    '#<TinyIRC::Bot>'
  end
end
