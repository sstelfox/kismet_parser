# -*- encoding: utf-8 -*-
require File.expand_path('../lib/kismet_parser/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Sam Stelfox"]
  gem.email         = ["sstelfox+gems@bedroomprogrammers.net"]
  gem.homepage      = ""
  
  gem.description   = %q{A parser for kismet output logs into a sqlite database}
  gem.name          = "kismet_parser"
  gem.summary       = %q{Parses kismet logs into a sqlite database}
  gem.version       = KismetParser::VERSION

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "nokogiri"
  gem.add_dependency "sqlite3"
  gem.add_dependency "json"
  gem.add_development_dependency "rspec"
end
