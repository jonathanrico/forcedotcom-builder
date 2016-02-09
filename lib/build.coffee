child_process = require 'child_process'
fs = require 'fs'
qs = require 'querystring'

BuildView = require './build-view'

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
    atom.commands.add 'atom-workspace', 'build:sf-deploy', => @deploy()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-static-res', => @deployStaticRes()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-apex', => @deployApex()
    atom.commands.add 'atom-workspace', 'build:sf-deploy-visualforce', => @deployVisualforce()
    atom.commands.add 'atom-workspace', 'build:sf-retrieve-unpackaged', => @retrieveUnpackaged()
    atom.commands.add 'atom-workspace', 'build:sf-retrieve-unpackaged-file', => @retrieveSingleFile()
    atom.commands.add 'atom-workspace', 'build:sf-abort', => @stop()

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

  startNewBuild:(buildTarget,params) ->
    if(params)
      cmd = @buildSingleFileCommand(buildTarget,params)
    else
      cmd = @buildCommand(buildTarget)
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
    if @child then @abort(=> @startNewBuild('deploy')) else @startNewBuild('deploy')

  deployStaticRes: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy-static-res')) else @startNewBuild('deploy-static-res')

  deployApex: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy-apex')) else @startNewBuild('deploy-apex')

  deployVisualforce: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('deploy-visualforce')) else @startNewBuild('deploy-visualforce')

  retrieveUnpackaged: ->
    clearTimeout @finishedTimer
    if @child then @abort(=> @startNewBuild('retrieve-unpackaged')) else @startNewBuild('retrieve-unpackaged')

  deploySingleFile: ->
    @processSingleFile('deploy')

  retrieveSingleFile: ->
    @processSingleFile('retrieve')

  processSingleFile: (optype) ->
    if(@isDeployRunning())
      clearTimeout @finishedTimer
      if(atom.workspace.getActiveTextEditor().buffer?.file?)

        path = atom.workspace.getActiveTextEditor().buffer.file.path
        projectPath = @root+'/src/'
        pathHeRegex = ///#{projectPath}///
        if(path.match(pathHeRegex))
          fileBaseName = atom.workspace.getActiveTextEditor().buffer.file.getBaseName()
          folderNamePath = path.replace ///#{fileBaseName}///, ''
          folderNamePath = folderNamePath.replace pathHeRegex, ''
          folderName = folderNamePath.split "/"
          fileName = fileBaseName.split "."
          if(fileName.length > 1)
            fileNameParsed = if fileName.length > 2 then fileName[0]+'.'+fileName[1] else fileName[0]
          metaDataType = null
          switch folderName[0]
            when 'classes'
              metaDataType = 'ApexClass'
            when 'triggers'
              metaDataType = 'ApexTrigger'
            when 'pages'
              metaDataType = 'ApexPage'
            when 'components'
              metaDataType = 'ApexComponent'
            when 'staticresources'
              metaDataType = 'StaticResource'
            when 'applications'
              metaDataType = 'CustomApplication'
            when 'objects'
              metaDataType = 'CustomObject'
            when 'tabs'
              metaDataType = 'CustomTab'
            when 'layouts'
              metaDataType = 'Layout'
            when 'quickActions'
              metaDataType = 'QuickAction'
            when 'profiles'
              metaDataType = 'Profile'
            when 'labels'
              metaDataType = 'CustomLabels'
            when 'workflows'
              metaDataType = 'Workflow'
            when 'remoteSiteSettings'
              metaDataType = 'RemoteSiteSetting'
            when 'permissionsets'
              metaDataType = 'PermissionSet'
            when 'letterhead'
              metaDataType = 'Letterhead'
            when 'translations'
              metaDataType = 'Translations'
            when 'groups'
              metaDataType = 'Group'
            when 'objectTranslations'
              metaDataType = 'CustomObjectTranslation'
            when 'communities'
              metaDataType = 'Network'
            when 'reportTypes'
              metaDataType = 'ReportType'
            when 'settings'
              metaDataType = 'Settings'
            when 'assignmentRules'
              metaDataType = 'AssignmentRule'
            when 'approvalProcesses'
              metaDataType = 'ApprovalProcess'
            when 'escalationRules'
              metaDataType = 'EscalationRule'
            when 'flows'
              metaDataType = 'Flow'
            when 'aura'
              metaDataType = 'AuraDefinitionBundle'
            when 'documents'
              metaDataType = 'Document'
            else
              metaDataType = null

          if(metaDataType != null)
            params = [fileNameParsed,metaDataType,folderName[0]]
            if metaDataType == 'AuraDefinitionBundle' || metaDataType == 'Document'
                params.push(folderName[1])
            if @child then @abort(=> @startNewBuild(optype+'-single-file',params)) else @startNewBuild(optype+'-single-file',params)
          else
            @buildView.buildUnsupported()

        else
          @buildView.buildUnsupported()

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
