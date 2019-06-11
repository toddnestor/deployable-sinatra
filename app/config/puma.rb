# frozen_string_literal: true

File
  .open('README.md', 'r') { |file| file.each_line.take(8)}
  .map { |line| line.strip.ljust(43).center(100) }
  .join("\n")
  .then(&method(:puts))

port 4000
