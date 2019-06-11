# Add colors to the rails console
require "awesome_print"
AwesomePrint.pry!

require_relative './pry_startup.rb' if File.file?('./pry_startup.rb')

Pry.prompt = [
  proc { |target_self, nest_level, pry|
    "[#{pry.input_ring.size}]\001\e[0;32m\002#{Pry.config.prompt_name}\001\e[0m\002(\001\e[0;33m\002#{Pry.view_clip(target_self)}\001\e[0m\002)#{":#{nest_level}" unless nest_level.zero?}> "
  },
  proc { |target_self, nest_level, pry|
    "[#{pry.input_ring.size}]\001\e[1;32m\002#{Pry.config.prompt_name}\001\e[0m\002(\001\e[1;33m\002#{Pry.view_clip(target_self)}\001\e[0m\002)#{":#{nest_level}" unless nest_level.zero?}* "
  }
]
