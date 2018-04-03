@cookie_qualities = {
  'normal'    => '',
  'uncommon'  => '%C%LBLUEuncommon ',
  'rare'      => '%C%BLUErare ',
  'epic'      => '%C%PURPLEepic ',
  'legendary' => '%C%YELLOWlegendary ',
  'holy'      => '%C%ORANGEholy ',
  'hi-tech'   => '%C%CYANhi-tech ',
  'quantum'   => '%C%LBLUEquantum ',
  'evil'      => '%C%BLACKevil ',
  'magical'   => '%C%PURPLEmagical ',
  'ancient'   => '%C%LBLUEancient ',
  'vampiric'  => '%C%REDvampiric '
}

@cookie_types = {
  'normal'      => '',
  'blazing'     => '%C%ORANGEblazing ',
  'hot'         => '%C%REDhot ',
  'frozen'      => '%C%CYANfrozen ',
  'chilling'    => '%C%LBLUEchilling ',
  'shocking'    => '%C%YELLOWshocking ',
  'aerial'      => '%C%LGREYaerial ',
  'stone'       => '%C%GREYstone ',
  'mud'         => '%C%BROWNmud ',
  'void'        => '%C%BLACKvoid ',
  'ghostly'     => '%C%WHITEghostly ',
  'bloody'      => '%C%REDbloody ',
  'nyan'        => '%C%REDn%C%GREENy%C%BLUEa%C%CYANn ',
  'teleporting' => '%C%CYANteleporting ',
  'wild'        => '%C%BROWNwild ',
  'alient'      => '%C%GREENalien ',
  'spacious'    => '%C%BLACKspacious ',
  'atomic'      => '%C%REDatomic ',
  'chocolate'   => '%C%BROWNchocolate '
}

group('world') do |g|
  g.perm @name, 'cookie', 'invoker'
  g.perm @name, 'cookie', 'targeted'
end

def generate(e, c, targeted)
  quality = @cookie_qualities[c.options['quality']] || @cookie_qualities.values.sample
  type = @cookie_types[c.options['type']] || @cookie_types.values.sample  
  target = if targeted
    c.positionals['who']
  else
    e[:nick]
  end
  "ACTION %Ngives %B#{target}%N a %B#{quality}#{type}%N%B%C%BROWNcookie%N"
end

cookie_cmd = cmd 'cookie'

cookie_cmd.branch('invoker', '--quality=QUALITY --type=TYPE') do |e, c|
  e[:socket].ctcp(e[:reply_to], generate(e, c, false))
end.tap do |b|
  b.cooldown = 10
  b.description = 'Gives you a cookie'
  b.definition.tap do |d|
    d.description :option, 'quality', 'The cookie quality (optional)'
    d.description :option, 'type', 'The cookie type (optional)'
  end
end

cookie_cmd.branch('targeted', 'who --quality=QUALITY --type=TYPE') do |e, c|
  e[:socket].ctcp(e[:reply_to], generate(e, c, true))
end.tap do |b|
  b.cooldown = 10
  b.description = 'Gives a cookie to the given user'
  b.definition.tap do |d|
    d.description :positional, 'who', 'User to give cookie to'
    d.description :option, 'quality', 'The cookie quality (optional)'
    d.description :option, 'type', 'The cookie type (optional)'
  end
end