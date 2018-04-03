module TinyIRC
  def self.define_event_methods(h)
    h.define_singleton_method :reply do |msg|
      raise RuntimeError, ':reply action is not supported' unless self[:reply_to]
      self[:socket].privmsg(self[:reply_to], msg)
    end
    h.define_singleton_method :nreply do |msg|
      raise RuntimeError, ':nreply action is not supported' unless self[:nick]
      self[:socket].notice(self[:nick], msg)
    end
  end
end