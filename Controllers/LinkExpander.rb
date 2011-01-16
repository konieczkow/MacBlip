# -------------------------------------------------------
# LinkExpander.rb
#
# Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
# Licensed under Eclipse Public License v1.0
# -------------------------------------------------------

class LinkExpander
  def self.sharedLinkExpander
    @@instance ||= LinkExpander.new
  end

  def initialize
    @links = {}
  end

  def register(shortLink, expandedLink)
    @links[shortLink] = expandedLink
  end

  def expand(shortLink)
    if shortLink =~ %r{^(http://rdir.pl/\w+)}
      @links[$1]
    end
  end
end
