child_process = require 'child_process'
fs = require 'fs'

module.exports =
  isWin: () ->
    /^win/.test process.platform

  getPlatformPath: (str) ->
    if @isWin() then str.replace /\//g, '\\' else str

  getSrcPath: (root) ->
    root + @getPlatformPath('/src/')

#-----------

  getSfCreatingItemParams: (sfCreatingDialog, root) ->
    params = {}
    params.srcPath = @getSrcPath(root)
    params.metaDataType = "Apex" + sfCreatingDialog.itemType
    if sfCreatingDialog.itemType == "Class"
      params.extension = "cls"
      params.fldPath = params.srcPath + @getPlatformPath('classes/')
      params.srcLines = ["public with sharing class " + sfCreatingDialog.apiName + " {\n    \n}"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<status>Active</status>"
      ]
    else if sfCreatingDialog.itemType == "Trigger"
      params.extension = "trigger"
      params.fldPath = params.srcPath + @getPlatformPath('triggers/')
      params.srcLines = [
        "trigger " + sfCreatingDialog.apiName + " on SObject_Api_Name (before update) {"
        "    if (Trigger.isBefore) {"
        "        if (Trigger.isUpdate) {"
        "            "
        "        }"
        "    }"
        "}"
      ]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<status>Active</status>"
      ]
    else if sfCreatingDialog.itemType == "Page"
      params.extension = "page"
      params.fldPath = params.srcPath + @getPlatformPath('pages/')
      params.srcLines = ["<apex:page>\n    <h1>This is new page!</h1>\n</apex:page>"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<availableInTouch>false</availableInTouch>"
        "<confirmationTokenRequired>false</confirmationTokenRequired>"
        "<label>" + sfCreatingDialog.label + "</label>"
      ]
    else if sfCreatingDialog.itemType == "Component"
      params.extension = "component"
      params.fldPath = params.srcPath + @getPlatformPath('components/')
      params.srcLines = ["<apex:component>\n    <h1>This is new component!</h1>\n</apex:component>"]
      params.metaLines = [
        "<apiVersion>" + sfCreatingDialog.apiVersion + "</apiVersion>"
        "<label>" + sfCreatingDialog.label + "</label>"
      ]
    params.srcFilePath = params.fldPath + sfCreatingDialog.apiName + "." + params.extension
    params.metaFilePath = params.srcFilePath + "-meta.xml"
    params

#-----------

  writeFile: (filePath, lines) ->
    fh = fs.createWriteStream filePath
    for line in lines
       fh.write(line + "\n")
    fh.end("")

  writeMeta: (itemParams) ->
    lines = []
    lines.push "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<" + itemParams.metaDataType + " xmlns=\"http://soap.sforce.com/2006/04/metadata\">"
    for metaLine in itemParams.metaLines
      lines.push "    " + metaLine
    lines.push "</" + itemParams.metaDataType + ">"
    @writeFile itemParams.metaFilePath, lines
    itemParams.metaFilePath

  writeSrc: (itemParams) ->
    @writeFile itemParams.srcFilePath, itemParams.srcLines
    itemParams.srcFilePath

#-----------

  createSfItem: (sfCreatingDialog, root) ->
    itemParams = @getSfCreatingItemParams(sfCreatingDialog, root)
    @writeMeta itemParams
    @writeSrc itemParams

#-----------

  deleteFolderRecursive: (path) ->
    if fs.existsSync(path)
      fs.readdirSync(path).forEach (file, index) =>
        curPath = path + "/" + file
        if fs.lstatSync(curPath).isDirectory()
          @deleteFolderRecursive(curPath);
        else
          fs.unlinkSync(curPath);
      fs.rmdirSync(path);

#-----------

  runProcess: (child, view, command, args, beforeCommand, afterCommand, onclose) ->
    if beforeCommand
      beforeCommand()
    child = child_process.exec(command, args)
    child.stdout.on 'data', view.append
    child.stderr.on 'data', view.append
    child.on "close", onclose
    if afterCommand
      afterCommand()

#-----------

  getMetaDataFromFolderName: (folderName) ->
    folderMapping = {
      'classes' : 'ApexClass'
      ,'triggers' : 'ApexTrigger'
      ,'pages' : 'ApexPage'
      ,'components' : 'ApexComponent'
      ,'staticresources' : 'StaticResource'
      ,'applications' : 'CustomApplication'
      ,'objects' : 'CustomObject'
      ,'tabs' : 'CustomTab'
      ,'layouts' : 'Layout'
      ,'quickActions' : 'QuickAction'
      ,'profiles' : 'Profile'
      ,'labels' : 'CustomLabels'
      ,'workflows' : 'Workflow'
      ,'remoteSiteSettings' : 'RemoteSiteSetting'
      ,'permissionsets' : 'PermissionSet'
      ,'letterhead' : 'Letterhead'
      ,'translations' : 'Translations'
      ,'groups' : 'Group'
      ,'objectTranslations' : 'CustomObjectTranslation'
      ,'communities' : 'Network'
      ,'reportTypes' : 'ReportType'
      ,'settings' : 'Settings'
      ,'assignmentRules' : 'AssignmentRule'
      ,'approvalProcesses' : 'ApprovalProcess'
      ,'escalationRules' : 'EscalationRule'
      ,'flows' : 'Flow'
      ,'aura' : 'AuraDefinitionBundle'
      ,'documents' : 'Document'
      ,'email' : 'EmailTemplate'
    }
    result = null
    if folderMapping.hasOwnProperty folderName
      result = folderMapping[folderName]
    result
