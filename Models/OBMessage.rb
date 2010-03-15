# -------------------------------------------------------
# OBMessage.rb
#
# Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
# Licensed under GPL v3 license
# -------------------------------------------------------

class OBMessage

  def senderAndRecipient
    case messageType
      when OBStatusMessage then user.login
      when OBDirectedMessage then "#{user.login} > #{recipient.login}"
      when OBPrivateMessage then "#{user.login} >> #{recipient.login}"
    end
  end

  def keyPathsForValuesAffectingSenderAndRecipient
    NSSet.setWithObjects("messageType", "user", "recipient", nil)
  end

  def sanitizeTag(tag)
    # remove accented characters, i.e. replace "ó" with "o" etc.
    # first, separate characters and accents
    decomposed = tag.downcase.decomposedStringWithCanonicalMapping

    # now, remove everything that is not a letter or digit
    goodChars = NSCharacterSet.characterSetWithCharactersInString("0123456789abcdefghijklmnopqrstuvwxyz")
    decomposed.componentsSeparatedByCharactersInSet(goodChars.invertedSet).componentsJoinedByString('')
  end

  def detectLinks(richText, regexp)
    richText.string.scan(regexp) do
      url = yield
      if url && url.length > 0
        offset = $~.offset(0)
        range = NSRange.new(offset.first, offset.last - offset.first)
        richText.addAttribute(NSLinkAttributeName, value: NSURL.URLWithString(url), range: range)
      end
    end
  end

  def processedBody
    text = body
    text += " [FOTO]" if pictures && pictures.length > 0
    richText = NSMutableAttributedString.alloc.initWithString(text, attributes: {})

    detectLinks(richText, /\#([^\s\!\@\#\$\%\^\&\*\(\)\[\]\-\_\+\=\{\}\:\;\'\"\\\|\,\.\<\>\?\/\`\~]+)/) do
      BLIP_WWW_HOST + "/tags/#{sanitizeTag($1)}"
    end
    detectLinks(richText, /\^(\w+)/) { BLIP_WWW_HOST + "/users/#{$1}/dashboard" }
    detectLinks(richText, /\b(\w+\:\/\/[^\s]+)/) { $1 }
    detectLinks(richText, /\[FOTO\]$/) { pictures && pictures.first && pictures.first['url'] }

    richText
  end

  def keyPathsForValuesAffectingProcessedBody
    NSSet.setWithObjects("body", "pictures", nil)
  end

end
