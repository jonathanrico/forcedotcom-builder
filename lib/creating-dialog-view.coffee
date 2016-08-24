module.exports =
class SfDialog

  constructor: ->
  	someComponent = document.createElement("div");
  	someComponent.setAttribute("hello","helloami");
  	someComponent.style.width="100%";
  	someComponent.style.height="100px";
  	@somePanel = atom.workspace.addModalPanel(item: someComponent);
  	someComponent.addEventListener("click", () -> 
  		@somePanel.destroy(); #It's not working now
  	)