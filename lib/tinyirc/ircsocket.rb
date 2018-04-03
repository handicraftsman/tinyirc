class TinyIRC::IRCSocket
  attr_accessor :name, :host, :port, :nick, :user, :pass, :rnam, :autojoin, :prefix
  attr_accessor :bot, :reconnects, :running, :last_write
  attr_reader :mtx, :log, :sock, :queue, :usercache

  def initialize(bot, name, opts)
    @bot  = bot
    @name = name
    @host = opts['host'] || '127.0.0.1'
    @port = opts['port'] || 6667
    @nick = opts['nick'] || 'TinyBot'
    @user = opts['user'] || @nick
    @pass = opts['pass'] || nil
    @rnam = opts['rnam'] || 'An IRC bot in Ruby'
    @autojoin = opts['autojoin'] || []
    @prefix = opts['prefix'] || bot.prefix || '!'
    
    @reconnects = 0
    @running = false
    @last_write = Time.now

    @mtx = Mutex.new
    @log = ParticleLog.new("!#{name}", ParticleLog::INFO)
    @log.level_table[ParticleLog::IO] = 'IRC'
    @log.important "Hello, #{name}!"
  
    @sock = nil
    @queue = Queue.new
    @usercache = TinyIRC::UserCache.new
  end

  def connect(reconnect=false)
    @log.important 'Connecting...'
    @mtx.synchronize do
      begin
        @sock = TCPSocket.new @host, @port
        @running = true
        @bot.handle_event type: :connect, socket: self
        Thread.new do
          authenticate
        end
      rescue => e
        @log.error "#{e.class.name} - #{e.message}"
        @bot.handle_event type: :disconnect, socket: self
      end
    end
  end

  def disconnect
    @mtx.synchronize do
      @running = false
      sock.close
    end
  end

  def authenticate
    direct_write "PASS #{@pass}" if @pass
    direct_write "NICK #{@nick}"
    direct_write "USER #{@user} 0 * :#{@rnam}"
  end

  def direct_write(msg)
    log.io "W> #{msg}"
    @sock.write "#{msg}\r\n"
  end

  def write(msg)
    @queue.push msg
  end

  def inspect
    "#<TinyIRC::IRCSocket @name=#{@name.inspect}>"
  end

  def has_perm(host, name)
    if (@bot.db.execute(
      'SELECT EXISTS(SELECT 1 FROM groupinfo WHERE server=? AND host=? AND name="admin" LIMIT 1)',
      [@name, host]
    ).flatten[0] == 1)
      return true
    end

    groups = @bot.db.execute("SELECT name FROM groupinfo WHERE server=? AND host=?", [@name, host])
    groups = groups.flatten.to_set
    groups << 'world'
    
    def where(gname)
      s = gname.split('/', 2)
      if s.length == 1
        @bot.groups[gname]
      elsif s.length == 2
        return nil unless @bot.plugins.include? s[0]
        @bot.plugins[s[0]].groups[gname]
      else
        nil
      end

    end

    groups.each do |gname|
      w = where(gname)
      next unless w
      w.perms.each do |perm|
        if perm == TinyIRC::Permission.new(*TinyIRC::Permission.parse(name))
          return true
        end
      end
    end

    false
  end

  def set_group(host, name)
    res = @bot.db.execute(
      'SELECT EXISTS(SELECT 1 FROM groupinfo WHERE server=? AND host=? AND name=? LIMIT 1)',
      [@name, host, name]
    ).flatten[0]
    if res == 0
      @bot.db.execute('INSERT INTO groupinfo (server, host, name) VALUES (?, ?, ?)', [@name, host, name])
    end
  end

  def del_group(host, name)
    @bot.db.execute('DELETE FROM groupinfo WHERE server=? AND host=? AND name=?', [@name, host, name])
  end

  def has_group(host, name)
    if (@bot.db.execute(
      'SELECT EXISTS(SELECT 1 FROM groupinfo WHERE server=? AND host=? AND name="admin" LIMIT 1)',
      [@name, host]
    ).flatten[0] == 0) then
      @bot.db.execute(
        'SELECT EXISTS(SELECT 1 FROM groupinfo WHERE server=? AND host=? AND name=? LIMIT 1)',
        [@name, host, name]
      ).flatten[0] == 1
    else
      true
    end
  end

  def list_groups(host)
    @bot.db.execute(
      'SELECT name FROM groupinfo WHERE server=? AND host=?',
      [@name, host]
    ).flatten
  end

  def join(chan, key = nil)
    if key
      write "JOIN #{chan} #{key}"
    else
      write "JOIN #{chan}"
    end
  end

  def part(chan, reason = 'Bye')
    write "PART #{chan} :#{reason}"
  end

  def self.ssplit(string)
    out = []
    arr = string.split("\n\r")
    arr.each do |i|
      items = i.scan(/.{,399}/)
      items.delete('')
      items.each do |i2|
        out << i2
      end
    end
    out
  end

  def self.process_colors(string)
    string
      .gsub("%C%",     "%C?")
      .gsub(",%",      ",?")
      .gsub("%C",      "\x03")
      .gsub("%B",      "\x02")
      .gsub("%I",      "\x10")
      .gsub("%U",      "\x1F")
      .gsub("%N",      "\x0F")
      .gsub("?WHITE",  "0")
      .gsub("?BLACK",  "1")
      .gsub("?BLUE",   "2")
      .gsub("?GREEN",  "3")
      .gsub("?RED",    "4")
      .gsub("?BROWN",  "5")
      .gsub("?PURPLE", "6")
      .gsub("?ORANGE", "7")
      .gsub("?YELLOW", "8")
      .gsub("?LGREEN", "9")
      .gsub("?CYAN"  , "10")
      .gsub("?LCYAN",  "11")
      .gsub("?LBLUE",  "12")
      .gsub("?PINK",   "13")
      .gsub("?GREY",   "14")
      .gsub("?LGREY",  "15")
  end

  def privmsg(target, message)
    self.class.ssplit(self.class.process_colors(message)).each do |m|
      write("PRIVMSG #{target} :\u200B#{m}")
    end
  end

  def notice(target, message)
    self.class.ssplit(self.class.process_colors(message)).each do |m|
      write("NOTICE #{target} :\u200B#{m}")
    end
  end

  def ctcp(target, message)
    write("PRIVMSG #{target} :\x01#{self.class.process_colors(message)}\x01")
  end

  def nctcp(target, message)
    write("NOTICE #{target} :\x01#{self.class.process_colors(message)}\x01")
  end

  def mode(channel, params)
    write("MODE #{channel} #{params}")
  end

  def kick(channel, target, reason = 'Bye!')
    write("KICK #{channel} #{target} :#{reason}")
  end

  def remove(channel, target, reason = 'Bye!')
    write("REMOVE #{channel} #{target} :#{reason}")
  end
end