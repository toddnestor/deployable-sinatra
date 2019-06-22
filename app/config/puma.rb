# frozen_string_literal: true

File
  .open('README.md', 'r') { |file| file.each_line.take(8)}
  .then(&method(:puts))

port 4000
