# Tinyirc

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'particlecmd'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install particlecmd
```

## Usage

Sample config file:

```yaml
plugins:
  path/to/plugin: # The same path as in the `require` function
    # This table can be empty if you want to load the plugin without configuring it
    # Plugins may require some values from this table though
    # You can always load plugins from installed gems (if you are using bundler)
    foo: bar

groups:
  world: # All users belong to this group
    include: # Includes permissions from listed groups into the current one
      - plugin/world
    perms:
      - core/flushq
  admin: # Admins have this group
    include:
      - world
      - plugin/admin
  owner: # Owners have this group
    include:
      - admin
      - plugin/owner

cooldowns:
  plugin: 30 # Sets cooldown for plugin/*/* commands to 30 seconds
  plugin/command: 20 # Sets cooldown for plugin/command/* commands to 20 seconds
  plugin/command/branch: 10 # Sets cooldown for plugin/command/branch command to 10 seconds

servers:
  freenode:
    host: irc.freenode.net
    port: 6667

    nick: YourNicknameHere
    user: YourUsernameHere
    pass: YourPasswordHere
    rnam: YourRealnameHere

    prefix: '@'

    autojoin:
      - '#botters-test'
```

To start the bot, simply execute:

```bash
$ bundler exec tinyirc -c /path/to/config.yaml -d /path/to/db.db # both options are optional
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/handicraftsman/tinyirc.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

