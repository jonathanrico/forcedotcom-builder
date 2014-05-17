child_process = require 'child_process'
fs = require 'fs'
qs = require 'querystring'

BuildView = require './build-view'

module.exports =
  configDefaults:
    environment: "",
    arguments: ""

  activate: (state) ->
    @root = atom.project.getPath()
    @buildView = new BuildView()
    atom.workspaceView.command "build:sf-deploy-file", => @deploySingleFile()
    atom.workspaceView.command "build:sf-deploy", => @deploy()
    atom.workspaceView.command "build:sf-deploy-static-res", => @deployStaticRes()
    atom.workspaceView.command "build:sf-deploy-apex", => @deployApex()
    atom.workspaceView.command "build:sf-deploy-visualforce", => @deployVisualforce()
    atom.workspaceView.command "build:sf-abort", => @stop()

  deactivate: ->
    @child.kill('SIGKILL')

  buildCommand:(target) ->
    cmd = 'ant '+target+' -f '+@root + '/build/build.xml'
    return cmd

  buildSingleFileCommand:(target,params) ->
    cmd = 'ant '+target+' -Ddeploy.single.folderName='+params[2]+' -Ddeploy.single.fileName="'+params[0]+'" -Ddeploy.single.metadataType='+params[1]+' -f '+@root + '/build/build.xml'
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
      console.log('exitCode is : '+exitCode)
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

  deploySingleFile: ->
    if(@isDeployRunning())
      clearTimeout @finishedTimer
      if(atom.workspace.getActiveEditor().buffer?.file?)

        path = atom.workspace.getActiveEditor().buffer.file.path
        projectPath = @root+'/app/src/'
        pathHeRegex = ///#{projectPath}///
        if(path.match(pathHeRegex))
          fileBaseName = atom.workspace.getActiveEditor().buffer.file.getBaseName()
          folderNamePath = path.replace ///#{fileBaseName}///, ''
          folderNamePath = folderNamePath.replace pathHeRegex, ''
          folderName = folderNamePath.split "/"
          fileName = fileBaseName.split "."
          if(fileName.length > 1)
            fileNameParsed = if fileName.length > 2 then fileName[0]+'.'+fileName[1] else fileName[0]
          console.log(fileNameParsed)
          metaDataType = null
          switch folderName[0]
            when 'classes'
              metaDataType = 'ApexClass'
            when 'trigger'
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
              metaDataType = 'WorkflowRule'
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
            else
              metaDataType = null

          if(metaDataType != null)
            params = [fileNameParsed,metaDataType,folderName[0]]
            if @child then @abort(=> @startNewBuild('deploy-single-file',params)) else @startNewBuild('deploy-single-file',params)
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
      alert "Hmmm! There's another deploy running."
      return false
    else
      return true
