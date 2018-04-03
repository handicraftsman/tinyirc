class TinyIRC::UserCache
  def initialize
    @cache = {}
  end

  def get(nick, add = true)
    if add
      @cache[nick] ||= { nick: nick }
      @cache[nick]
    else
      @cache[nick] || { nick: nick }
    end
  end

  def set(entry)
    @cache[entry[:nick]] = entry
  end

  def rename(o, n)
    @cache[n] = @cache.delete(o) if @cache[o]
    @cache[n][:nick] = n
    @cache[n]
  end
end