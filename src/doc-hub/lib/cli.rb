#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'

class CLI < Thor
  desc "hello NAME", "Say hello to NAME"
  def hello(name)
    puts "Hello #{name}!"
  end

  desc "goodbye NAME", "Say goodbye to NAME"
  def goodbye(name)
    puts "Goodbye #{name}!"
  end

  desc "version", "Show version"
  def version
    puts "doc-hub v1.0.0"
  end
end
