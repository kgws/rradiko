require 'rubygems'
gem 'hoe', '>= 2.1.0'
require 'hoe'
require 'fileutils'
require './lib/rradiko'

Hoe.plugin :newgem

$hoe = Hoe.spec 'rradiko' do
  self.version = RRadiko::VERSION
  self.developer 'kgws', 'dev.kgws@gmail.com'
  self.url = 'http://github.com/kgws/rradiko'
  self.post_install_message = 'PostInstall.txt' 
  self.summary = "rradiko (recording radiko.jp)"
  self.description = "This program is for you to Radio loves. This program can record a radio show from radiko.jp. If I was to copyright infringement, please contact(github.com/inbox/new/kgws). "
  self.extra_deps         = [
  ]
end

task :default => [:spec, :features]
require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }
