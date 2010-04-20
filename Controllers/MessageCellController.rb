# -------------------------------------------------------
# MessageCellController.rb
#
# Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
# Licensed under GPL v3 license
# -------------------------------------------------------

class MessageCellController < SDListViewItem

  attr_accessor :dateLabel, :textView, :pictureView

  TEXT_VIEW_HORIZONTAL_PADDING = 10  # approximate value, based on experiments :)
  MINIMUM_CELL_HEIGHT = 72           # likewise

  def self.dateFormatter
    @dateFormatter ||= HumanReadableDateFormatter.new
  end

  def loadView
    super
    dateLabel.formatter = self.class.dateFormatter

    # pull text view out of its scroll view (we can't do that in IB, Bad Things happen then)
    scrollView = textView.enclosingScrollView
    frame = scrollView.frame
    scrollView.removeFromSuperview
    textView.frame = frame
    self.view.addSubview(textView)

    if self.representedObject.hasPicture
      frame = textView.frame
      frame.size.width -= pictureView.frame.size.width
      textView.frame = frame
    end

    @heightOutsideTextView = self.view.frame.size.height - textView.frame.size.height
    @widthOutsideTextView = self.view.frame.size.width - textView.frame.size.width

    self.view.menu = createContextMenu
    self.view.subviews.each { |v| v.menu = self.view.menu }
  end

  def createContextMenu
    menu = NSMenu.alloc.initWithTitle ""
    menu.addItemWithTitle "Quote...", action: 'quoteActionSelected:', keyEquivalent: ''
    if representedObject.user.login != OBConnector.sharedConnector.account.username
      menu.addItemWithTitle "Reply...", action: 'replyActionSelected:', keyEquivalent: ''
    end
    if representedObject.pictures && representedObject.pictures.length > 0
      menu.addItemWithTitle "Show picture...", action: 'showPictureActionSelected:', keyEquivalent: ''
    end
    menu.delegate = self
    menu
  end

  def heightForGivenWidth(newCellWidth)
    newTextWidth = newCellWidth - @widthOutsideTextView - TEXT_VIEW_HORIZONTAL_PADDING
    # TODO: count attributed string size ?
    boxForTextView = textView.string.boundingRectWithSize(
      NSMakeSize(newTextWidth, 2000),
      options: NSStringDrawingUsesLineFragmentOrigin,
      attributes: {}
    )
    pictureHeight = self.representedObject.hasPicture ? pictureView.frame.size.height : 0
    newCellHeight = @heightOutsideTextView + [boxForTextView.size.height, pictureHeight].max

    [newCellHeight, MINIMUM_CELL_HEIGHT].max
  end

  def avatarClicked(sender)
    BrowserController.openUsersDashboard(self.representedObject.user.login)
  end

end
