class TinyIRC::Command
  class << self
    attr_reader :log
  end

  @log = ParticleLog.new('commands', ParticleLog::INFO)

  class Branch
    attr_reader :cmd, :id, :definition, :handler, :last_uses
    attr_accessor :cooldown, :description

    def initialize(cmd, id, definition, handler)
      @cmd         = cmd
      @cooldown    = 0
      @id          = id
      @definition  = definition
      @description = ''
      @handler     = handler
      @last_uses   = {}
    end
  end
  
  attr_reader :plugin, :name, :branches
  
  def initialize(plugin, name)
    @plugin   = plugin
    @name     = name
    @branches = {}
    TinyIRC::Command.log.info "commands += #{@plugin.name}/#{name}"
  end

  def branch(id, definition, &handler)
    @branches[id] = Branch.new(self, id, ParticleCMD::Definition.from_string(@name, definition), handler)
    TinyIRC::Command.log.info "#{@plugin.name}/#{@name} += #{id}: #{@branches[id].definition.command_signature(true)}"
    @branches[id]
  end

  def handle_command(h, cmd_info)
    pname = h[:cmd_info][:plugin]
    pname = @plugin.name if pname == :any
    cname = h[:cmd_info][:command]
    bname = h[:cmd_info][:branch]
    
    def checkperm(h, fname)
      h[:socket].has_perm(h[:host], fname)
    end

    def checkcd(h, branch)
      return true if h[:socket].has_group(h[:host], 'admin')
      unless branch.last_uses[h[:socket].name]
        branch.last_uses[h[:socket].name] = {}
        return true
      end
      current = Time.now.to_i
      last = branch.last_uses[h[:socket].name][h[:nick]].to_i
      diff = current - last
      if diff >= branch.cooldown || diff < 0
        branch.last_uses[h[:socket].name][h[:nick]] = current
        true
      else
        false
      end
    end

    if (bname != :any)
      if @branches.include? bname
        branch = @branches[bname]
        res = branch.definition.match cmd_info
        if res
          bname = branch.id
          fname = pname + '/' + cname + '/' + bname
          unless checkperm(h, fname)
            h.nreply "Sorry, but you cannot execute this command (#{fname})"
            return :denied
          end
          unless checkcd(h, branch)
            h.nreply "Sorry, but you cannot execute this command now (cooldown - #{branch.cooldown}s)"
            return :cooldown
          end
          branch.handler.(h, res)
          true
        else
          false
        end
      else
        false
      end
    else
      @branches.each_pair do |id, branch|
        res = branch.definition.match cmd_info
        if res
          bname = branch.id
          fname = pname + '/' + cname + '/' + bname
          unless checkperm(h, fname)
            h.nreply "Sorry, but you cannot execute this command (#{fname})"
            return :denied
          end
          unless checkcd(h, branch)
            h.nreply "Sorry, but you cannot execute this command now (cooldown - #{branch.cooldown}s)"
            return :cooldown
          end
          branch.handler.(h, res)
          return true
        end
      end
      false
    end
  end
end