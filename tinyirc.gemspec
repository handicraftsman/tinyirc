
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tinyirc/version'

Gem::Specification.new do |spec|
  spec.name          = 'tinyirc'
  spec.version       = TinyIRC::VERSION
  spec.authors       = ['Nickolay Ilyushin']
  spec.email         = ['nickolay02@inbox.ru']

  spec.summary       = 'A modular IRC bot framework'
  spec.description   = 'A modular IRC bot framework'
  spec.homepage      = 'https://github.com/handicraftsman/tinyirc'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 12.3'

  spec.add_dependency 'particlecmd', '~> 0.1'
  spec.add_dependency 'particlelog', '~> 0.1'
  spec.add_dependency 'sinatra', '~> 2.0'
  spec.add_dependency 'thin', '~> 1.7'
  spec.add_dependency 'sqlite3', '~> 1.3'
end
