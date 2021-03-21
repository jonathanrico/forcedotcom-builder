{MessagePanelView, LineMessageView, PlainMessageView} = require 'atom-message-panel'

module.exports =
class BuildView

  constructor: ->
    @messagepanel = new MessagePanelView title: 'Force.com Builder', rawTitle: false, recentMessagesAtTop: true

  addMessage: (msg, type) =>
    @messagepanel.setTitle msg
    @messagepanel.add new PlainMessageView message: msg, className: type

  reset: =>
    clearTimeout @titleTimer if @titleTimer
    clearTimeout @abortTimer if @abortTimer
    @abortTimer = null
    @titleTimer = null
    @resetPanel()

  close: (event, element) =>
    @resetPanel()

  buildStarted: =>
    @reset()
    @messagepanel.setTitle('Building...',true)
    @messagepanel.attach()

  buildFinished: (success) =>
    text = if success then 'Build successful! :)' else 'Build failed :('
    textclass = if success then 'text-success' else 'text-error'
    if success
        atom.notifications.addSuccess("Build successful! :)", dismissable: true)
    else
        atom.notifications.addError("Build failed :(", dismissable: true)

    @addMessage(text,textclass)
    @messagepanel.setTitle(text,true)
    clearTimeout @titleTimer if @titleTimer

  buildAborted: =>
    @addMessage('Aborted','text-error')
    @messagepanel.attach()
    atom.notifications.addWarning("Build aborted", dismissable: true)
    clearTimeout @titleTimer if @titleTimer
    @abortTimer = setTimeout @reset, 1000

  buildUnsupported: =>
    @buildStarted()
    @addMessage('Unsupported File','text-error')
    clearTimeout @titleTimer if @titleTimer
    @abortTimer = setTimeout @reset, 1000

  append: (line) =>
    line = line.toString()
    @addMessage(line,'text-info')

  resetPanel: =>
    @messagepanel.close()
    @messagepanel.clear()
