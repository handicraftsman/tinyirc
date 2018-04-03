class TinyIRC::Permission
  attr_reader :plugin, :command, :branch
  
  def self.parse(pstr)
    a = pstr.split('/', 3)
    raise RuntimeError, "Invalid permission: #{pstr}" unless a[0] || !a[1] && a[2]
    [a[0], a[1] || :all, a[2] || :all]
  end

  def initialize(plugin, command, branch)
    @plugin  = plugin
    @command = command
    @branch  = branch
  end

  def ==(other)
    @plugin == other.plugin && @command == other.command && @branch == other.branch
  end

  def to_s
    "#{@plugin}/#{@command}/#{@branch}"
  end
end

class TinyIRC::Group
  class << self
    attr_reader :log
  end

  @log = ParticleLog.new('groups', ParticleLog::INFO)

  attr_reader :name, :perms

  def initialize(name)
    @name  = name
    @perms = Set.new
    TinyIRC::Group::log.write "groups += #{name}"
  end

  def perm(plugin, command, branch)
    if @perms.add?(TinyIRC::Permission.new(plugin, command, branch))
      TinyIRC::Group::log.write "#{@name} += #{plugin}/#{command}/#{branch}"
    end
  end
end