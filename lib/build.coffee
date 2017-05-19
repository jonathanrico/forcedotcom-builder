shell = require 'shell'
fs = require 'fs'
qs = require 'querystring'
pathModule = require 'path'
remote = require "remote"

utils = require './utils'
BuildView = require './build-view'
SfCreatingDialog = require './sf-creating-dialog'
ProjectDialog = require './project-dialog'
CustomLabelDialog = require './custom-label-dialog'

module.exports =
  config:
    environment: "",
    arguments: ""

  activate: (state) ->
    @buildView = new BuildView()

    atom.commands.add 'atom-workspace', 'force.com:generate-project', => @generateProject()
    atom.commands.add 'atom-workspace', 'force.com:go-to-wiki', => @goToWiki()

    atom.commands.add 'atom-workspace', 'force.com:deploy-project', => @getProjectPath("treeview-project", @deploy, null)
    atom.commands.add 'atom-workspace', 'force.com:deploy-static-res', => @getProjectPath("treeview-project", @deployStaticRes, null)
    atom.commands.add 'atom-workspace', 'force.com:deploy-apex', => @getProjectPath("treeview-project", @deployApex, null)
    atom.commands.add 'atom-workspace', 'force.com:deploy-visualforce', => @getProjectPath("treeview-project", @deployVisualforce, null)
    atom.commands.add 'atom-workspace', 'force.com:retrieve-project', => @getProjectPath("treeview-project", @retrieveUnpackaged, null)

    atom.commands.add 'atom-workspace', 'force.com:deploy-current-file', => @getProjectPath("editor", @deploySingleFile, null)
    atom.commands.add 'atom-workspace', 'force.com:retrieve-current-file', => @getProjectPath("editor", @retrieveSingleFile, null)

    atom.commands.add 'atom-workspace', 'force.com:deploy-file-treeview', => @getProjectPath("treeview-single", @deploySingleFileTreeView, null)
    atom.commands.add 'atom-workspace', 'force.com:retrieve-file-treeview', => @getProjectPath("treeview-single", @retrieveSingleFileTreeView, null)

    atom.commands.add 'atom-workspace', 'force.com:deploy-selected-files', => @getProjectPath("treeview-multiple", @deploySeveralFiles, null)
    atom.commands.add 'atom-workspace', 'force.com:retrieve-selected-files', => @getProjectPath("treeview-multiple", @retrieveSeveralFiles, null)

    atom.commands.add 'atom-workspace', 'force.com:new-apex-class', => @getProjectPath("treeview-project", @creatingDialog, ["Class"])
    atom.commands.add 'atom-workspace', 'force.com:new-apex-trigger', => @getProjectPath("treeview-project", @creatingDialog, ["Trigger"])
    atom.commands.add 'atom-workspace', 'force.com:new-vf-page', => @getProjectPath("treeview-project", @creatingDialog, ["Page"])
    atom.commands.add 'atom-workspace', 'force.com:new-vf-component', => @getProjectPath("treeview-project", @creatingDialog, ["Component"])

    atom.commands.add 'atom-workspace', 'force.com:create-custom-label-editor', => @getProjectPath("editor", @createCustomLabelDialog, ["editor"])
    atom.commands.add 'atom-workspace', 'force.com:create-custom-label-project', => @getProjectPath("treeview-project", @createCustomLabelDialog, ["project"])

    atom.commands.add 'atom-workspace', 'force.com:abort', => @stop()

  getProjectPath: (projectSelector, callback, callbackArgs) ->
    root = null
    treeViewInstance = @getTreeView()
    if (projectSelector == "treeview-project" && treeViewInstance.selectedPaths()?)
      selectedPaths = treeViewInstance.selectedPaths()
      if (selectedPaths.length == 1)
        if (selectedPaths[0] in atom.project.getPaths())
          root = selectedPaths[0]
    else if (projectSelector == "editor")
      if atom.workspace.getActiveTextEditor()?.getPath()?
        [root, relativePath] = atom.project.relativizePath(atom.workspace.getActiveTextEditor().getPath())
    else if (projectSelector == "treeview-single")
      selectedPaths = treeViewInstance.selectedPaths()
      if (selectedPaths.length == 1)
        [root, relativePath] = atom.project.relativizePath(selectedPaths[0])
    else if (projectSelector == "treeview-multiple")
      selectedPaths = treeViewInstance.selectedPaths()
      if (selectedPaths.length > 0)
        [tmpRoot, relativePath] = atom.project.relativizePath(selectedPaths[0])
        for selectedPath in selectedPaths
          [cmpRoot, relativePath] = atom.project.relativizePath(selectedPath)
          if (tmpRoot != cmpRoot)
            tmpRoot = null
            break
        root = tmpRoot

    if (root == null && atom.project.getPaths().length > 0)
      if (atom.project.getPaths().length == 1)
        root = atom.project.getPaths()[0]
      else
        new ProjectDialog(this, callback, callbackArgs)
        return

    if (atom.project.getPaths()?.length <= 0)
      atom.notifications.addError("Your project has no project folders", dismissable: true);

    if (root != null)
      @root = root;
      if (callback)
        callback.apply(this, callbackArgs)

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

    utils.runProcess(@child, @buildView, cmd, args, null, @buildView.buildStarted, (exitCode) =>
      @buildView.buildFinished(0 == exitCode)
      @child = null
    )

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
      params.metaDataType = utils.getMetaDataFromFolderName(params.folderName[0])
    return params

  processSingleFile: (optype, cmdtype) ->
    if(@isDeployRunning())
      clearTimeout @finishedTimer
      path = null
      treeViewInstance = @getTreeView()
      if(cmdtype == 'editor' && atom.workspace.getActiveTextEditor()?.buffer?.file?)
        path = atom.workspace.getActiveTextEditor().buffer.file.path
      else if(cmdtype == 'treeview' && treeViewInstance.selectedPaths()?)
        path = treeViewInstance.selectedPaths()[0]
      if(path)
        projectPath = utils.getSrcPath(@root)
        fileParams = @getFileDetails(utils.isWin(), projectPath, path)
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
      treeViewInstance = @getTreeView()
      if (treeViewInstance.selectedPaths()?.length > 0)
          params = {}
          projectPath = utils.getSrcPath(@root)
          paths = treeViewInstance.selectedPaths()
          for key, path of paths
              fileParams = @getFileDetails(utils.isWin(), projectPath, path)
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

  getTreeView: ->
    result = null;
    if (atom.packages.getActivePackage('tree-view')?.mainModule.getTreeViewInstance?)
      result = atom.packages.getActivePackage('tree-view').mainModule.getTreeViewInstance()
    else if (atom.packages.getActivePackage('tree-view')?.mainModule.createView?)
      result = atom.packages.getActivePackage('tree-view').mainModule.createView()
    result;

  creatingDialog: (itemType) ->
    new SfCreatingDialog(itemType, this);

  createSfItem: (sfCreatingDialog, callback) ->
    atom.workspace.open utils.createSfItem(sfCreatingDialog, @root)
    if callback
      callback()

  generateProject: () ->
    newProjectPath = remote.dialog.showOpenDialog({
      title:'Create Project',
      buttonLabel:'Generate'
      properties:['openDirectory', 'createDirectory']
    });
    if typeof newProjectPath == 'undefined'
      return;
    newProjectPath = newProjectPath[0]

    args = {
      encoding: 'utf8',
      timeout: 0,
      maxBuffer: 2000*1024,
      killSignal: 'SIGTERM',
      cwd: newProjectPath,
      env: null
    }

    utils.runProcess(@child, @buildView, 'git init', args, null, @buildView.buildStarted, (exitcode) =>
      utils.runProcess(@child, @buildView, 'git remote add origin https://github.com/jonathanrico/forcedotcom-project.git', args, null, null, (exitcode) =>
        utils.runProcess(@child, @buildView, 'git pull origin master', args, null, null, (exitcode) =>
          utils.runProcess(@child, @buildView, 'git init', args, () ->
            utils.deleteFolderRecursive utils.getPlatformPath(newProjectPath + '/.git')
          , null, (exitcode) =>
            fs.createReadStream(
              utils.getPlatformPath(newProjectPath + '/build/sample-sfdc-build.properties')
            ).pipe(
              fs.createWriteStream(utils.getPlatformPath(newProjectPath + '/build/sfdc-build.properties'))
            );
            atom.project.addPath(utils.getPlatformPath(newProjectPath))
            atom.workspace.open(utils.getPlatformPath(newProjectPath + '/build/sfdc-build.properties'))
            @child = null
            @buildView.buildFinished(true)
          )
        )
      )
    )

  goToWiki: () ->
    shell.openExternal 'https://github.com/jonathanrico/forcedotcom-builder/wiki'

  createCustomLabelDialog: (src) ->
    new CustomLabelDialog(
      src,
      if src == "editor" then atom.workspace.getActiveTextEditor() else null,
      this
    );

  createCustomLabel: (customLabelDialog, callback) ->
    utils.insertCustomLabel customLabelDialog, @root, customLabelDialog.editor
    if callback
      callback()
