# -------------------------------------------------------
# MainWindowController.rb
#
# Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
# Licensed under GPL v3 license
# -------------------------------------------------------

class MainWindowController < NSWindowController

  LAST_GROWLED_KEY = "growl.lastGrowledMessageId"
  GROWL_LIMIT = 5

  attr_accessor :listView, :scrollView, :spinner, :loadingView, :newMessageButton, :dashboardButton

  def init
    initWithWindowNibName "MainWindow"
    @lastGrowled = NSUserDefaults.standardUserDefaults.integerForKey(LAST_GROWLED_KEY) || 0
    @firstLoad = true
    self
  end

  def windowDidLoad
    @blip = OBConnector.sharedConnector
    mbObserve(@blip.dashboardMonitor, OBDashboardUpdatedNotification, 'dashboardUpdated:')
    mbObserve(@blip.dashboardMonitor, OBDashboardUpdateFailedNotification, 'dashboardUpdateFailed:')
    mbObserve(@blip.dashboardMonitor, OBDashboardWillUpdateNotification, :dashboardWillUpdate)

    window.setContentBorderThickness(32, forEdge: NSMinYEdge)
    window.movableByWindowBackground = true

    @listView.bind "content", toObject: OBMessage, withKeyPath: "list", options: nil
    @listView.sortDescriptors = [NSSortDescriptor.sortDescriptorWithKey('date', ascending: true)]
    @listView.topPadding = 5
    @listView.bottomPadding = 5
    # the order is actually descending, but listView is not flipped so it counts Y coordinate from bottom... o_O

    @spinner.startAnimation(self)
  end

  def warningBar
    if @warningBar.nil?
      @warningBar = WarningBar.alloc.initWithType(:warning)
      @warningBar.text = tr("Blip is currently overloaded…")
      window.contentView.addSubview(@warningBar)
    end
    @warningBar
  end

  def errorBar
    if @errorBar.nil?
      @errorBar = WarningBar.alloc.initWithType(:error)
      @errorBar.text = tr("Connection to the server has failed.")
      window.contentView.addSubview(@errorBar)
    end
    @errorBar
  end

  def showWarningBar
    unless warningBar.displayed
      if errorBar.displayed
        warningBar.removeFromSuperview
        window.contentView.addSubview(warningBar)
        errorBar.slideOut
      end
      @scrollView.contentView.copiesOnScroll = false
      warningBar.slideIn
    end
  end

  def showErrorBar
    unless errorBar.displayed
      if warningBar.displayed
        errorBar.removeFromSuperview
        window.contentView.addSubview(errorBar)
        warningBar.slideOut
      end
      @scrollView.contentView.copiesOnScroll = false
      errorBar.slideIn
    end
  end

  def hideNoticeBars
    [@warningBar, @errorBar].compact.each { |b| b.slideOut if b.displayed }
    @scrollView.contentView.copiesOnScroll = true
  end

  def windowDidResize(notification)
    @listView.viewDidEndLiveResize unless window.inLiveResize
  end

  def dashboardWillUpdate
    @spinner.startAnimation(self)
  end

  def scrollToTop
    scrollView.verticalScroller.floatValue = 0
    scrollView.contentView.scrollToPoint(NSZeroPoint)
  end

  def dashboardUpdated(notification)
    messages = notification.userInfo["messages"]
    if messages && messages.count > 0
      self.performSelector('scrollToTop', withObject: nil, afterDelay: 0.2) if @firstLoad
      messagesWithPictures = messages.find_all { |m| m.hasPicture }
      messagesWithPictures.each { |m| @blip.loadPictureRequest(m).sendFor(self) }
      growlMessages(messages)
      @lastGrowled = [@lastGrowled, messages.first.recordIdValue].max
      NSUserDefaults.standardUserDefaults.setInteger(@lastGrowled, forKey: LAST_GROWLED_KEY)
    end

    @loadingView.psHide
    @newMessageButton.psEnable
    @dashboardButton.psEnable
    @spinner.stopAnimation(self)
    @firstLoad = false
    hideNoticeBars
  end

  def dashboardUpdateFailed(notification)
    error = notification.userInfo["error"]
    if error.blipTimeoutError?
      if OBMessage.list.empty?
        obprint "MainWindowController: first dashboard update failed, retrying"
        @blip.dashboardMonitor.performSelector('forceUpdate', withObject: nil, afterDelay: 10.0)
      else
        obprint "MainWindowController: dashboard update failed, ignoring"
        showWarningBar
        @spinner.stopAnimation(self)
      end
    else
      @loadingView.psHide
      showErrorBar
      @spinner.stopAnimation(self)
    end
  end

  def requestFailedWithError(error)
    request = error.userInfo['request']
    if request.didFinishSelector == :'pictureLoaded:'
      obprint "MainWindowController: picture load error, ignored"
    else
      obprint "MainWindowController: load error: #{error.localizedDescription}"
    end
  end

  def pictureLoaded(data, forMessage: message)
    # ok, ignore
  end

  def newMessagePressed(sender)
    openNewMessageWindow
  end

  def quoteActionSelected(sender)
    message = sender.menu.delegate.representedObject
    openNewMessageWindow("#{message.url} ")
  end

  def replyActionSelected(sender)
    message = sender.menu.delegate.representedObject
    symbol = (message.messageType == OBPrivateMessage) ? ">>" : ">"
    openNewMessageWindow("#{symbol}#{message.user.login}: ")
  end

  def showPictureActionSelected(sender)
    message = sender.menu.delegate.representedObject
    BrowserController.openAttachedPicture(message)
  end

  def openNewMessageWindow(text = nil)
    if @newMessageDialog.nil?
      @newMessageDialog = NewMessageDialogController.alloc.initWithMainWindowController(self, text: text)
    end
    @newMessageDialog.showWindow(self)
  end

  def newMessageDialogClosed
    @newMessageDialog = nil
  end

  def dashboardPressed(sender)
    BrowserController.openDashboard
  end

  def displayLoadingError(error)
    psShowAlertSheet(tr("Error"), error.localizedDescription)
  end

  def growlMessages(messages)
    myLogin = @blip.account.username

    # don't growl own messages, or those that have been growled before
    growlableMessages = messages.find_all { |m| m.user.login != myLogin && m.recordIdValue > @lastGrowled }

    if growlableMessages.count > GROWL_LIMIT + 1
      growlableMessages.first(GROWL_LIMIT).each { |m| sendGrowlNotification(m) }
      sendGroupedGrowlNotification(growlableMessages[GROWL_LIMIT..-1])
    else
      growlableMessages.each { |m| sendGrowlNotification(m) }
    end
  end

  def sendGroupedGrowlNotification(messages)
    users = messages.map(&:user).map(&:login).sort.uniq.join(", ")
    last_digit = messages.count % 10
    template = tr((last_digit >= 2 && last_digit <= 4) ? "AND_2_TO_4_OTHER_UPDATES" : "AND_5_OR_MORE_OTHER_UPDATES")
    GrowlApplicationBridge.notifyWithTitle(
      template % messages.count,
      description: "#{tr('From:')} #{users}",
      notificationName: "Status group received",
      iconData: nil,
      priority: 0,
      isSticky: false,
      clickContext: nil
    )
  end

  def sendGrowlNotification(message)
    growlType = case message.messageType
      when OBPrivateMessage, OBDirectedMessage then "Directed message received"
      else "Status received"
    end
    GrowlApplicationBridge.notifyWithTitle(
      message.senderAndRecipient,
      description: message.bodyForGrowl,
      notificationName: growlType,
      iconData: message.user.fixedAvatarData,
      priority: 0,
      isSticky: false,
      clickContext: nil
    )
  end

  def displayImageInQuickLook(message)
    @messageInQuickLook = message
    panel = QLPreviewPanel.sharedPreviewPanel
    if panel.isVisible
      updateQuickLookPosition
    else
      panel.makeKeyAndOrderFront(self)
    end
  end

  def updateQuickLookPosition
    panel = QLPreviewPanel.sharedPreviewPanel

    # I know this doesn't make sense, but if this line *isn't* called, every second time the image that
    # gets displayed in the panel is the one at index 0, instead of the one that was clicked. with this
    # line, it works correctly. I have no idea why, ask Steve, he's got the source code.
    panel.currentPreviewItemIndex = 0

    panel.currentPreviewItemIndex = messagesWithPictures.index(@messageInQuickLook)
  end

  def acceptsPreviewPanelControl(panel)
    true
  end

  def beginPreviewPanelControl(panel)
    panel.dataSource = self
    updateQuickLookPosition
  end

  def endPreviewPanelControl(panel)
  end

  def messagesWithPictures
    OBMessage.list.find_all { |m| m.hasPicture }
  end

  def numberOfPreviewItemsInPreviewPanel(panel)
    messagesWithPictures.length
  end

  def previewPanel(panel, previewItemAtIndex: index)
    message = messagesWithPictures[index]
    QuickLookPicture.new(message.pictures.first)
  end

end
