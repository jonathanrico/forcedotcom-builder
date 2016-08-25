child_process = require 'child_process'
fs = require 'fs'
qs = require 'querystring'
pathModule = require 'path'

BuildView = require './build-view'
SfCreatingDialog = require './sf-creating-dialog'

module.exports =
  config:
    environment: "",
    arguments: ""

  activate: (state) ->
    project_paths = atom.project.getPaths()
    if !project_paths
        return

    @root = project_paths[0]
    @buildView = new BuildView()

    atom.commands.add 'atom-workspace', 'build:sf-deploy-file', => @deploySingleFile()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-file-treeview', => @deploySingleFileTreeView()
    atom.commands.add 'atom-workspace', 'build:sf-deploy', => @deploy()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-static-res', => @deployStaticRes()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-apex', => @deployApex()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-visualforce', => @deployVisualforce()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-several-files', => @deploySeveralFiles()
    atom.commands.add 'atom-workspace', 'build:sf-retrieve-unpackaged', => @retrieveUnpackaged()
    atom.commands.add 'atom-workspace', 'build:sf-retrieve-unpackaged-file', => @retrieveSingleFile()
    atom.commands.add 'atom-workspace', 'build:sf-retrieve-unpackaged-file-treeview', => @retrieveSingleFileTreeView()
    atom.commands.add 'atom-workspace', 'build:sf-abort', => @stop()
    atom.commands.add 'atom-workspace', 'build:sf-retrieve-several-files', => @retrieveSeveralFiles()
    atom.commands.add 'atom-workspace', 'forcedotcom-builder:create-apex-class', => @creatingDialog("Class")
    atom.commands.add 'atom-workspace', 'forcedotcom-builder:create-apex-trigger', => @creatingDialog("Trigger")
    atom.commands.add 'atom-workspace', 'forcedotcom-builder:create-vf-page', => @creatingDialog("Page")
    atom.commands.add 'atom-workspace', 'forcedotcom-builder:create-vf-component', => @creatingDialog("Component")

  deactivate: ->
    @child.kill('SIGKILL')

  buildCommand:(target) ->
    cmd = 'ant '+target+' -f '+@root + '/build/build.xml'
    return cmd

  buildSingleFileCommand:(target,params) ->
    cmd = 'ant '+target
    optype = if (target == 'deploy-single-file') then 'deploy' else 'retrieve'
    if params.length > 3
        cmd += ' -D'+optype+'.single.subFolderName='+params[3]
    cmd += ' -D'+optype+'.single.folderName='+params[2]+' -D'+optype+'.single.fileName="'+params[0]+'" -D'+optype+'.single.metadataType='+params[1]+' -f '
    cmd += @root + '/build/build.xml'
    return cmd

  buildSeveralFilesCommand:(optype, jsonParam) ->
    optype = if (optype == 'deploy') then 'deploy' else 'retrieve'
    cmd = 'ant ' + optype + '-several-files'
    if jsonParam
        cmd += ' -D' + optype + '.several.json="' + jsonParam + '"'
    cmd += ' -f ' + @root + '/build/build.xml'
    return cmd

  startNewBuild:(buildTarget, params, buildType) ->
    switch buildType
        when 'build'
            cmd = @buildCommand(buildTarget)
        when 'buildSingle'
            cmd = @buildSingleFileCommand(buildTarget, params)
        when 'buildSeveral'
            cmd = @buildSeveralFilesCommand(buildTarget, params)
        else
            return if !cmd

    args = {
      encoding: 'utf8',
      timeout: 0,
      maxBuffer: 2000*1024, #increased buffer size
      killSignal: 'SIGTERM',
      cwd: null,
      env: null
    }

    @child = child_process.exec(cmd,args)

    @child.stdout.on 'data', @buildView.append
    @child.stderr.on 'data', @buildView.append
    @child.on 'close', (exitCode) =>
      @buildView.buildFinished(0 == exitCode)
      @child = null

    @buildView.buildStarted()

  abort: (cb) ->
    @child.removeAllListeners 'close'
    @child.on 'close', =>
      @child = null
      cb() if cb
    @child.kill()

  deploy: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy', null, 'build')) else @startNewBuild('deploy', null, 'build')

  deployStaticRes: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy-static-res', null, 'build')) else @startNewBuild('deploy-static-res', null, 'build')

  deployApex: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy-apex', null, 'build')) else @startNewBuild('deploy-apex', null, 'build')

  deployVisualforce: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy-visualforce', null, 'build')) else @startNewBuild('deploy-visualforce', null, 'build')

  retrieveUnpackaged: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('retrieve-unpackaged', null, 'build')) else @startNewBuild('retrieve-unpackaged', null, 'build')

  deploySingleFile: ->
    @processSingleFile('deploy','editor')

  retrieveSingleFile: ->
    @processSingleFile('retrieve','editor')

  deploySingleFileTreeView: ->
    @processSingleFile('deploy','treeview')

  retrieveSingleFileTreeView: ->
    @processSingleFile('retrieve','treeview')

  getFileDetails: (isWin, projectPath, path) ->
    params = null
    if(path.startsWith(projectPath))
      params = {}
      params.fileBaseName = pathModule.basename(path)
      params.folderNamePath = path.replace ///#{params.fileBaseName}///, ''
      params.folderNamePath = params.folderNamePath.replace(projectPath, '')
      params.folderName =  if isWin then params.folderNamePath.split("\\") else params.folderNamePath.split "/"
      params.fileName = params.fileBaseName.split "."
      if(params.fileName.length > 1)
        params.fileNameParsed = if (params.fileName.length > 2 && (!/^.+\-meta$/.test(params.fileName[1]))) then params.fileName[0]+'.'+params.fileName[1] else params.fileName[0]
      params.metaDataType = null
      switch params.folderName[0]
        when 'classes'
          params.metaDataType = 'ApexClass'
        when 'triggers'
          params.metaDataType = 'ApexTrigger'
        when 'pages'
          params.metaDataType = 'ApexPage'
        when 'components'
          params.metaDataType = 'ApexComponent'
        when 'staticresources'
          params.metaDataType = 'StaticResource'
        when 'applications'
          params.metaDataType = 'CustomApplication'
        when 'objects'
          params.metaDataType = 'CustomObject'
        when 'tabs'
          params.metaDataType = 'CustomTab'
        when 'layouts'
          params.metaDataType = 'Layout'
        when 'quickActions'
          params.metaDataType = 'QuickAction'
        when 'profiles'
          params.metaDataType = 'Profile'
        when 'labels'
          params.metaDataType = 'CustomLabels'
        when 'workflows'
          params.metaDataType = 'Workflow'
        when 'remoteSiteSettings'
          params.metaDataType = 'RemoteSiteSetting'
        when 'permissionsets'
          params.metaDataType = 'PermissionSet'
        when 'letterhead'
          params.metaDataType = 'Letterhead'
        when 'translations'
          params.metaDataType = 'Translations'
        when 'groups'
          params.metaDataType = 'Group'
        when 'objectTranslations'
          params.metaDataType = 'CustomObjectTranslation'
        when 'communities'
          params.metaDataType = 'Network'
        when 'reportTypes'
          params.metaDataType = 'ReportType'
        when 'settings'
          params.metaDataType = 'Settings'
        when 'assignmentRules'
          params.metaDataType = 'AssignmentRule'
        when 'approvalProcesses'
          params.metaDataType = 'ApprovalProcess'
        when 'escalationRules'
          params.metaDataType = 'EscalationRule'
        when 'flows'
          params.metaDataType = 'Flow'
        when 'aura'
          params.metaDataType = 'AuraDefinitionBundle'
        when 'documents'
          params.metaDataType = 'Document'
        when 'email'
          params.metaDataType = 'EmailTemplate'
        else
          params.metaDataType = null
    return params

  processSingleFile: (optype, cmdtype) ->
    if(@isDeployRunning())
      clearTimeout @finishedTimer
      path = null
      if(cmdtype == 'editor' && atom.workspace.getActiveTextEditor()?.buffer?.file?)
        path = atom.workspace.getActiveTextEditor().buffer.file.path
      else if(cmdtype == 'treeview' && atom.packages.getActivePackage('tree-view')?.mainModule.createView().selectedPaths()?)
        path = atom.packages.getActivePackage('tree-view').mainModule.createView().selectedPaths()[0]
      if(path)
        isWin = /^win/.test(process.platform)
        projectPath = if isWin then @root+'\\src\\' else @root+'/src/'
        fileParams = @getFileDetails(isWin, projectPath, path)
        if(fileParams != null)
          if(fileParams.metaDataType != null)
            params = [fileParams.fileNameParsed, fileParams.metaDataType, fileParams.folderName[0]]
            if fileParams.metaDataType == 'AuraDefinitionBundle' || fileParams.metaDataType == 'Document' || fileParams.metaDataType == 'EmailTemplate'
                params.push(fileParams.folderName[1])
            if @child then @abort(=> @startNewBuild(optype+'-single-file', params, 'buildSingle')) else @startNewBuild(optype+'-single-file', params, 'buildSingle')
          else
            @buildView.buildUnsupported()
        else
          @buildView.buildUnsupported()

  deploySeveralFiles: ->
    @processSeveralFiles('deploy')

  retrieveSeveralFiles: ->
    @processSeveralFiles('retrieve')

  processSeveralFiles: (optype) ->
    if(@isDeployRunning())
      clearTimeout @finishedTimer
      if (atom.packages.getActivePackage('tree-view')?.mainModule.createView().selectedPaths()?.length > 0)
          params = {}
          isWin = /^win/.test(process.platform)
          projectPath = if isWin then @root+'\\src\\' else @root+'/src/'
          paths = atom.packages.getActivePackage('tree-view').mainModule.createView().selectedPaths()
          for key, path of paths
              fileParams = @getFileDetails(isWin, projectPath, path)
              if (fileParams? && fileParams.metaDataType? && fileParams.fileNameParsed?)
                  if !params[fileParams.metaDataType]?
                      params[fileParams.metaDataType] = {"fld" : fileParams.folderName[0],"items" : []}
                  if fileParams.metaDataType == 'AuraDefinitionBundle'
                      if fileParams.folderName[1] not in params[fileParams.metaDataType].items && fileParams.folderName[1].length > 0
                          params[fileParams.metaDataType].items.push(fileParams.folderName[1])
                  else if fileParams.metaDataType == 'Document' || fileParams.metaDataType == 'EmailTemplate'
                      subFld = null;
                      for subItem in params[fileParams.metaDataType].items
                          if subItem.subfld == fileParams.folderName[1] && fileParams.folderName[1].length > 0
                              subFld = subItem;
                              break;
                      if (subFld == null && fileParams.folderName[1].length > 0)
                          params[fileParams.metaDataType].items.push({"subfld":fileParams.folderName[1], "files":[]});
                          subFld = params[fileParams.metaDataType].items[params[fileParams.metaDataType].items.length-1];
                      if fileParams.fileNameParsed not in subFld.files
                          subFld.files.push(fileParams.fileNameParsed);
                  else
                      if fileParams.fileNameParsed not in params[fileParams.metaDataType].items && fileParams.fileNameParsed.length > 0
                          params[fileParams.metaDataType].items.push(fileParams.fileNameParsed)
          params = JSON.stringify(params).replace(/"/g, '\\"');
          if @child then @abort(=> @startNewBuild(optype, params, 'buildSeveral')) else @startNewBuild(optype, params, 'buildSeveral')

  stop: ->
    if @child
      @abort()
      @buildView.buildAborted()
    else
      @buildView.reset()

  isDeployRunning: ->
    if @child
      atom.notifications.addError("Hmm... a deployment process is already running.", dismissable: true)
      return false
    else
      return true

  creatingDialog: (itemType)->
    new SfCreatingDialog(itemType, this);