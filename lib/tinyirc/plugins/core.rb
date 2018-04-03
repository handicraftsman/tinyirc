@webaddr = "http://#{ENV['PUBLIC_HOST'] || ENV['HOST'] || '0.0.0.0'}:#{ENV['PUBLIC_PORT'] || ENV['PORT'] || 8080}"

#
# Helper methods
#

self.define_singleton_method :handle_event do |e|
  def notify_plugin(plugin, e)
    (plugin.event_handlers[e[:type]] || []).each do |h|
      begin
        h[:handler].(e) if e >= h[:pattern]
      rescue => e
        e.backtrace.each do |l|
          @log.error "- #{l}"
        end
        @log.error "#{e.class.name} - #{e.message}"
      end
    end
  end

  notify_plugin(self, e)
  
  @bot.plugins.each do |pname, plugin|
    next if plugin == self
    Thread.new do
      notify_plugin(plugin, e)
    end
  end
end

#
# Event handlers
#

# Connect
on :connect do |e|
  socket = e[:socket]
  socket.log.important 'Connected'
  socket.reconnects = 0
end

# Disconnect
on :disconnect do |e|
  socket = e[:socket]
  socket.sock.close if socket.sock
  socket.log.important 'Disconnected'
  if (socket.reconnects < 5)
    socket.log.important 'Reconnecting in 5 seconds'
    sleep 5
    socket.reconnects += 1
    socket.connect
  else
    socket.log.important 'Reconnect limit reached'
  end
end

rgx_ping = /^PING :(.+)$/i
rgx_code = /^:.+? (\d\d\d) .+? (.+)$/i
rgx_join = /^:(.+?)!(.+?)@(.+?) JOIN (.+)$/i
rgx_part = /^:(.+?)!(.+?)@(.+?) PART (.+?) :(.+)$/i
rgx_nick = /^:(.+?)!(.+?)@(.+?) NICK :(.+)$/i
rgx_privmsg = /^:(.+?)!(.+?)@(.+?) PRIVMSG (.+?) :(.+)$/i
rgx_notice = /^:(.+?)!(.+?)@(.+?) NOTICE (.+?) :(.+)$/i

# Raw
on :raw do |e|
  d = e[:raw_data]
  if    m = rgx_ping.match(d)
    self.handle_event(e.merge!(type: :ping, target: m[1]))
  elsif m = rgx_code.match(d)
    self.handle_event(e.merge!(type: :code, code: m[1].to_i, extra: m[2]))
  elsif m = rgx_join.match(d)
    self.handle_event(e.merge!(
      type: :join,
      nick: m[1],
      user: m[2],
      host: m[3],
      channel: m[4]      
    ))
  elsif m = rgx_part.match(d)
    self.handle_event(e.merge!(
      type: :part,
      nick: m[1],
      user: m[2],
      host: m[3],
      channel: m[4],
      reason: m[5]     
    ))
  elsif m = rgx_nick.match(d)
    self.handle_event(e.merge!(
      type: :nick,
      nick: m[1],
      user: m[2],
      host: m[3],
      new_nick: m[4]
    ))
  elsif m = rgx_privmsg.match(d)
    self.handle_event(e.merge!(
      type: :privmsg,
      nick: m[1],
      user: m[2],
      host: m[3],
      target: m[4],
      message: m[5],
      reply_to: if m[4] == e[:socket].nick then m[1] else m[4] end
    ))
  elsif m = rgx_notice.match(d)
    self.handle_event(e.merge!(
      type: :privmsg,
      nick: m[1],
      user: m[2],
      host: m[3],
      target: m[4],
      message: m[5],
      reply_to: if m[4] == e[:socket].nick then m[1] else m[4] end
    )) 
  end
end

# Ping
on :ping do |e|
  e[:socket].write "PONG :#{e[:target]}"
end

# Welcome Code
on :code, code: 001 do |e|
  s = e[:socket]
  s.autojoin.each do |chan|
    s.join chan
  end
end

# WHOREPLY code
rgx_whoreply = /^.+? (.+?) (.+?) .+? (.+?) .*$/
on :code, code: 352 do |e|
  m = rgx_whoreply.match(e[:extra])
  if m
    u = e[:socket].usercache.get(m[3])
    u[:user] = m[1]
    u[:host] = m[2]
  end
end

# Join
on :join do |e|
  s = e[:socket]
  if e[:nick] == s.nick
    s.write "WHO #{e[:channel]}"
  end

  u = s.usercache.get(e[:nick])
  u[:user] = e[:user]
  u[:host] = e[:host]
end

# Nick
on :nick do |e|
  s = e[:socket]
  if e[:nick] == s.nick
    s.nick = e[:new_nick]
  end

  u = s.usercache.rename(e[:nick], e[:new_nick])
  u[:user] = e[:user]
  u[:host] = u[:host]
end

# PRIVMSG
on :privmsg do |e|
  s = e[:socket]
  
  u = s.usercache.get(e[:nick])
  u[:user] = e[:user]
  u[:host] = e[:host]

  if e[:message][0, s.prefix.length] == s.prefix
    s = Shellwords.split(e[:message][s.prefix.length, e[:message].length-1])
    e[:type] = :cmd
    e[:cmd] = s[0]

    c = s[0].split('/', 3)
    if c.length == 1
      e[:cmd_info] = { plugin: :any, command: c[0], branch: :any }
    elsif c.length == 2
      e[:cmd_info] = { plugin: c[0], command: c[1], branch: :any }
    elsif c.length == 3
      e[:cmd_info] = { plugin: c[0], command: c[1], branch: c[2] }
    else
      raise RuntimeError, "Invalid command: #{s[0]}"
    end
    s.shift
    
    info = ParticleCMD::Info.new(s)
    e[:bot].handle_command(e, info || '')
  end
end

#
# Groups
#

group('world').tap do |g|
  g.perm @name, 'help', 'root'
  g.perm @name, 'help', 'what'

  g.perm @name, 'key', 'generate'
  g.perm @name, 'key', 'use'
end

group('admin').tap do |g|
  g.perm @name, 'reload', 'root'

  g.perm @name, 'groups',     'root'
  g.perm @name, 'groups-add', 'root'
  g.perm @name, 'groups-del', 'root'

  g.perm @name, 'flushq', 'root'
  g.perm @name, 'flushq', 'targeted'
end

#
# help command
#

help_cmd = cmd 'help'

help_cmd.branch('root', '') do |e, c|
  e.nreply "Open #{@webaddr}/ to get info about all available commands and groups"
end.description = 'Sends a link to the index help page'

help_cmd.branch('what', 'what') do |e, c|
  arr = c.positionals['what'].split('/', 3)
  if   arr.length == 1
    ok = false
    e[:bot].plugins.each_pair do |pname, plugin|
      plugin.commands.each do |cname, command|
        if cname == arr[0]
          e.nreply "Help for #{pname}/#{cname}: #{@webaddr}/#{pname}##{cname}"
          ok = true
          break
        end
      end
      break if ok
    end
    e.nreply "Cannot find such command" unless ok
  elsif arr.length == 2
    unless e[:bot].plugins.include? arr[0]
      e.nreply "Cannot find such plugin"
      next
    end
    pname = arr[0]
    plugin = e[:bot].plugins[pname]
    cname = arr[1]
    if plugin.commands.include? cname
      e.nreply "Help for #{pname}/#{cname}: #{@webaddr}/#{pname}##{cname}"
    else
      e.nreply "Cannot find such command"
    end
  elsif arr.length == 3
    pname = arr[0]
    plugin = e[:bot].plugins[pname]
    cname = arr[1]
    unless plugin.commands.include? cname
      e.nreply "Cannot find such command"
      next
    end
    command = plugin.commands[cname]
    bname = arr[2]
    unless command.branches.include? bname
      e.nreply "Cannot find such command branch"
      next
    end
    e.nreply "Help for #{pname}/#{cname}/#{bname}: #{@webaddr}/#{pname}##{cname}/#{bname}"
  end
end.tap do |b|
  b.description = 'Sends a link to the help page for the given command'
  b.definition.tap do |d|
    d.description :positional, 'what', <<~HELP
Command name. Can be in these forms:
      - command 
      - plugin/command
      - plugin/command/branch
HELP
  end
end

#
# key command
#

key_cmd = cmd 'key'

key_cmd.branch('generate', '') do |e, c|
  @key = Random.rand(44**44..55**55).to_s(36)
  @log.important @key
  e.nreply 'Done!'
end.tap do |b|
  b.description = 'Generates an unique key and prints it to the console'
end

key_cmd.branch('use', 'key') do |e, c|
  if c.positionals['key'] == @key
    e[:socket].set_group e[:host], 'admin'
    e.nreply 'Done!'
  else
    e.nreply 'Invalid!'
  end
  @key = nil
end.tap do |b|
  b.description = 'Gives you admin status if the given key is correct'
  b.definition.tap do |d|
    d.description :positional, 'key', 'The generated key'
  end
end

#
# reload command
#

reload_cmd = cmd 'reload'

reload_cmd.branch('root', '-all -plugins! -plugins -groups -cooldowns') do |e, c|
  all           = c.flags['all']
  plugins       = c.flags['plugins!']  || all
  plugin_config = c.flags['plugins']   || plugins || all
  groups        = c.flags['groups']    || plugins || all
  cooldowns     = c.flags['cooldowns'] || plugins || all
  
  bot = e[:bot]
  bot.config_mtx.synchronize do
    bot.config = YAML.parse_file(bot.config_file).to_ruby

    bot.prefix = bot.config['prefix'] || '!'
    bot.log.info "prefix = #{bot.prefix}"

    bot.plugins = {} if plugins

    bot.load_plugin_config   if plugin_config
    bot.load_group_config    if groups
    bot.load_cooldown_config if cooldowns
  end

  e.nreply 'Done!'
end.tap do |b|
  b.description = 'Reloads given parts of the bot'
  b.definition.tap do |d|
    d.description :flag, 'all',       'Relaod everything'
    d.description :flag, 'plugins!',  'Reload plugins (also reloads plugin configs, groups and cooldowns)'
    d.description :flag, 'plugins',   'Reload plugin configs'
    d.description :flag, 'groups',    'Reload groups'
    d.description :flag, 'cooldowns', 'Reload cooldowns'
  end
end

#
# groups command
#

groups_cmd = cmd 'groups'

groups_cmd.branch('root', 'who') do |e, c|
  s = e[:socket]
  who = e[:socket].usercache.get(c.positionals['who'], false)[:host] || c.positionals['who']
  e.nreply "#{who}'s groups: #{s.list_groups(who).join(', ')}"
end.tap do |b|
  b.description = 'Lists groups of the given user'
  b.definition.description :positional, 'who', 'Command target'
end

#
# groups-add command
#

groups_add_cmd = cmd 'groups-add'

groups_add_cmd.branch('root', 'who ...') do |e, c|
  s = e[:socket]
  who = s.usercache.get(c.positionals['who'], false)[:host] || c.positionals['who']
  c.extra.each do |gname|
    s.set_group(who, gname)
  end
  e.nreply 'Done!'
end.tap do |b|
  b.description = 'Gives user given groups'
  b.definition.description :positional, 'who', 'Command target'
end

#
# groups-del command
#

groups_del_cmd = cmd 'groups-del'

groups_del_cmd.branch('root', 'who ...') do |e, c|
  s = e[:socket]
  who = s.usercache.get(c.positionals['who'], false)[:host] || c.positionals['who']
  c.extra.each do |gname|
    s.del_group(who, gname)
  end
  e.nreply 'Done!'
end.tap do |b|
  b.description = 'Removes given groups from the user'
  b.definition.description :positional, 'who', 'Command target'
end

#
# flushq command
#

flushq_cmd = cmd 'flushq'

flushq_cmd.branch('root', '') do |e, c|
  e[:socket].queue.clear
  e.nreply 'Done!'
end.tap do |b|
  b.description = 'Flushes the queue of the current server'
end

flushq_cmd.branch('targeted', 'server') do |e, c|
  bot = e[:bot]
  if bot.sockets.include? c.positionals['server']
    bot.sockets[c.positionals['server']].queue.clear
    e.nreply 'Done!'
  else
    e.nreply 'There\'s no such server!'
  end
end.tap do |b|
  b.description = 'Flushes the queue of the given server'
end