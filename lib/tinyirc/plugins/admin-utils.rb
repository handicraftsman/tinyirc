#
# Groups
#

group('chanop').tap do |g|
  g.perm @name, 'kick',   'kick'
  g.perm @name, 'remove', 'remove'

  g.perm @name, 'ban', 'here'
  g.perm @name, 'unban', 'here'

  g.perm @name, 'exempt', 'here'
  g.perm @name, 'unexempt', 'here'

  g.perm @name, 'quiet', 'here'
  g.perm @name, 'unquiet', 'here'

  g.perm @name, 'voice', 'invoker'
  g.perm @name, 'voice', 'here'

  g.perm @name, 'devoice', 'invoker'
  g.perm @name, 'devoice', 'here'

  g.perm @name, 'op', 'invoker'
  g.perm @name, 'op', 'here'

  g.perm @name, 'deop', 'invoker'
  g.perm @name, 'deop', 'here'

  g.perm @name, 'hop', 'invoker'
  g.perm @name, 'hop', 'here'

  g.perm @name, 'dehop', 'invoker'
  g.perm @name, 'dehop', 'here'
end

group('admin').tap do |g|
  g.perm @name, 'raw', 'raw'

  g.perm @name, 'join', 'root'

  g.perm @name, 'part', 'root'
  g.perm @name, 'part', 'targeted'

  g.perm @name, 'ban', 'in'
  g.perm @name, 'unban', 'in'

  g.perm @name, 'exempt', 'in'
  g.perm @name, 'unexempt', 'in'
  
  g.perm @name, 'quiet', 'in'
  g.perm @name, 'unquiet', 'in'
  
  g.perm @name, 'voice', 'in'
  g.perm @name, 'devoice', 'in'
  
  g.perm @name, 'op', 'in'
  g.perm @name, 'deop', 'in'
  
  g.perm @name, 'hop', 'in'
  g.perm @name, 'dehop', 'in'
end

#
# raw command
#

cmd('raw').branch('raw', '...') do |e, c|
  e[:socket].write(c.extra.join(' '))
end.description = 'Sends the given message to the server'

#
# join command
#

join_cmd = cmd 'join'

join_cmd.branch('root', 'chan --pass=PASS') do |e, c|
  e[:socket].join(c.positionals['chan'], c.options['pass'] || nil)
end.tap do |b|
  b.description = 'Joins given channel'
  b.definition.description :option, 'pass', 'Channel password'
end

#
# part command
#

part_cmd = cmd 'part'

part_cmd.branch('root', '--reason=REASON') do |e, c|
  e[:socket].part(e[:target], c.options['reason'] || 'Bye!')
end

part_cmd.branch('targeted', 'chan --reason=REASON') do |e, c|
  e[:socket].part(c.positionals['chan'], c.options['reason'] || 'Bye!')
end.tap do |b|
  b.description = 'Parts given channel'
  b.definition.description :option, 'reason', 'Part reason'
end

#
# get target func
#

def get_target(e, c, raw)
  host = e[:socket].usercache.get(c.positionals['who'], false)[:host]
  if raw || host == nil
    c.positionals['who']
  else
    "*!*@#{host}"
  end
end

#
# kick command
#

cmd('kick').branch('kick', 'who --ban --reason=REASON') do |e, c|
  s = e[:socket]
  if c.flags['ban']
    to_ban = get_target(e, c, false)
    s.mode(e[:reply_to], "+b #{to_ban}")
  end
  s.kick(e[:reply_to], c.positionals['who'])
end.tap do |b|
  b.description = 'Kicks the given user from the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be kicked'
    d.description :flag, 'ban', 'Ban the given user'
    d.description :option, 'reason', 'Kick reason'
  end
end

#
# remove command
#

cmd('remove').branch('remove', 'who --ban --reason=REASON') do |e, c|
  s = e[:socket]
  if c.flags['ban']
    to_ban = get_target(e, c, false)
    s.mode(e[:reply_to], "+b #{to_ban}")
  end
  s.remove(e[:reply_to], c.positionals['who'])
end.tap do |b|
  b.description = 'Removes the given user from the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be removed'
    d.description :flag, 'ban', 'Ban the given user'
    d.description :option, 'reason', 'Remove reason'
  end
end

#
# ban command
#

ban_cmd = cmd('ban')

ban_cmd.branch('here', 'who --raw') do |e, c|
  e[:socket].mode(e[:target], "+b #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Bans the given user from the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be banned'
    d.description :flag, 'raw', 'Ban the given hostmask instead of the user\'s one'
  end
end

ban_cmd.branch('in', 'where who --raw') do |e, c|
  e[:socket].mode(c.positionals['where'], "+b #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Bans the given user from the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to ban in'
    d.description :positional, 'who', 'User to be banned'
    d.description :flag, 'raw', 'Ban the given hostmask instead of the user\'s one'
  end
end

#
# unban command
#

unban_cmd = cmd('unban')

unban_cmd.branch('here', 'who --raw') do |e, c|
  e[:socket].mode(e[:target], "-b #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Unbans the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be unbanned'
    d.description :flag, 'raw', 'Unban the given hostmask instead of the user\'s one'
  end
end

unban_cmd.branch('in', 'where who --raw') do |e, c|
  e[:socket].mode(c.positionals['where'], "-b #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Unbans the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to unban in'
    d.description :positional, 'who', 'User to be unbanned'
    d.description :flag, 'raw', 'Unban the given hostmask instead of the user\'s one'
  end
end

#
# exempt command
#

exempt_cmd = cmd('exempt')

exempt_cmd.branch('here', 'who --raw') do |e, c|
  e[:socket].mode(e[:target], "+e #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Exempts the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Exempt the given hostmask instead of the user\'s one'
  end
end

exempt_cmd.branch('in', 'where who --raw') do |e, c|
  e[:socket].mode(c.positionals['where'], "+e #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Exempts the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to exempt in'
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Exempt the given hostmask instead of the user\'s one'
  end
end

#
# unexempt command
#

unexempt_cmd = cmd('unexempt')

unexempt_cmd.branch('here', 'who --raw') do |e, c|
  e[:socket].mode(e[:target], "-e #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Unexempts the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Unexempt the given hostmask instead of the user\'s one'
  end
end

unexempt_cmd.branch('in', 'where who --raw') do |e, c|
  e[:socket].mode(c.positionals['where'], "-e #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Unexempts the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to exempt in'
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Unexempt the given hostmask instead of the user\'s one'
  end
end

#
# quiet command
#

quiet_cmd = cmd('quiet')

quiet_cmd.branch('here', 'who --raw') do |e, c|
  e[:socket].mode(e[:target], "+q #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Quiets the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Quiet the given hostmask instead of the user\'s one'
  end
end

quiet_cmd.branch('in', 'where who --raw') do |e, c|
  e[:socket].mode(c.positionals['where'], "-q #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Quiets the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to exempt in'
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Quiet the given hostmask instead of the user\'s one'
  end
end

#
# unquiet command
#

unquiet_cmd = cmd('unquiet')

unquiet_cmd.branch('here', 'who --raw') do |e, c|
  e[:socket].mode(e[:target], "-q #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Unquiets the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Unquiet the given hostmask instead of the user\'s one'
  end
end

unquiet_cmd.branch('in', 'where who --raw') do |e, c|
  e[:socket].mode(c.positionals['where'], "-q #{get_target(e, c, c.flags['raw'])}")
end.tap do |b|
  b.description = 'Unquiets the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to exempt in'
    d.description :positional, 'who', 'User to be exempted'
    d.description :flag, 'raw', 'Unquiet the given hostmask instead of the user\'s one'
  end
end

#
# voice command
#

voice_cmd = cmd('voice')

voice_cmd.branch('invoker', '') do |e, c|
  e[:socket].mode(e[:target], "+v #{e[:nick]}")
end.tap do |b|
  b.description = 'Voices you in the current channel'
end

voice_cmd.branch('here', 'who') do |e, c|
  e[:socket].mode(e[:target], "+v #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Voices the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be voiced'
  end
end

voice_cmd.branch('in', 'where who') do |e, c|
  e[:socket].mode(c.positionals['where'], "+v #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Voices the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to voice in'
    d.description :positional, 'who', 'User to be voiced'
  end
end

#
# devoice command
#

devoice_cmd = cmd('devoice')

devoice_cmd.branch('invoker', '') do |e, c|
  e[:socket].mode(e[:target], "-v #{e[:nick]}")
end.tap do |b|
  b.description = 'Devoices you in the current channel'
end

devoice_cmd.branch('here', 'who') do |e, c|
  e[:socket].mode(e[:target], "-v #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Devoices the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be devoiced'
  end
end

devoice_cmd.branch('in', 'where who') do |e, c|
  e[:socket].mode(c.positionals['where'], "-v #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Deoices the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to voice in'
    d.description :positional, 'who', 'User to be devoiced'
  end
end

#
# op command
#

op_cmd = cmd('op')

op_cmd.branch('invoker', '') do |e, c|
  e[:socket].mode(e[:target], "+o #{e[:nick]}")
end.tap do |b|
  b.description = 'Ops you in the current channel'
end

op_cmd.branch('here', 'who') do |e, c|
  e[:socket].mode(e[:target], "+o #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Ops the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be opd'
  end
end

op_cmd.branch('in', 'where who') do |e, c|
  e[:socket].mode(c.positionals['where'], "+o #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Ops the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to op in'
    d.description :positional, 'who', 'User to be opd'
  end
end

#
# deop command
#

deop_cmd = cmd('deop')

deop_cmd.branch('invoker', '') do |e, c|
  e[:socket].mode(e[:target], "-o #{e[:nick]}")
end.tap do |b|
  b.description = 'Deops you in the current channel'
end

deop_cmd.branch('here', 'who') do |e, c|
  e[:socket].mode(e[:target], "-o #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Deops the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be deopped'
  end
end

deop_cmd.branch('in', 'where who') do |e, c|
  e[:socket].mode(c.positionals['where'], "-o #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Deops the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to deop in'
    d.description :positional, 'who', 'User to be deopped'
  end
end

#
# hop command
#

hop_cmd = cmd('hop')

hop_cmd.branch('invoker', '') do |e, c|
  e[:socket].mode(e[:target], "+h #{e[:nick]}")
end.tap do |b|
  b.description = 'Half-Ops you in the current channel'
end

hop_cmd.branch('here', 'who') do |e, c|
  e[:socket].mode(e[:target], "+h #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Half-Ops the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be half-oppedd'
  end
end

hop_cmd.branch('in', 'where who') do |e, c|
  e[:socket].mode(c.positionals['where'], "+h #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Half-Ops the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to half-op in'
    d.description :positional, 'who', 'User to be half-oppedd'
  end
end

#
# dehop command
#

dehop_cmd = cmd('dehop')

dehop_cmd.branch('invoker', '') do |e, c|
  e[:socket].mode(e[:target], "-h #{e[:nick]}")
end.tap do |b|
  b.description = 'Dehalf-ops you in the current channel'
end

dehop_cmd.branch('here', 'who') do |e, c|
  e[:socket].mode(e[:target], "-h #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Dehalf-ops the given user in the current channel'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to be dehalf-opped'
  end
end

dehop_cmd.branch('in', 'where who') do |e, c|
  e[:socket].mode(c.positionals['where'], "-h #{c.positionals['who']}")
end.tap do |b|
  b.description = 'Dehalf-ops the given user in the given channel'
  b.definition.tap do |d|
    d.description :positional, 'where', 'Channel to dehalf-op in'
    d.description :positional, 'who', 'User to be dehalf-opped'
  end
end