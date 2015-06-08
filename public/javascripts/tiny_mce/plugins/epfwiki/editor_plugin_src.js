(function() {
	tinymce.create('tinymce.plugins.EPFWiki', {
		init : function(ed, url) {
			var t = this;

			t.editor = ed;

			// Register commands
			ed.addCommand('epfwikiUndoCheckout', t._undocheckout, t);
			ed.addCommand('epfwikiCheckin', t._checkin, t);
			ed.addCommand('epfwikiSave', t._save, t);
			//ed.addCommand('mceCancel', t._cancel, t);

			// Register example button
			ed.addButton('example', {
				title : 'example.desc',
				cmd : 'mceExample',
				image : url + '/img/example.gif'
			});

			// Register buttons
			ed.addButton('undocheckout', {title : 'Undo checkout', cmd : 'epfwikiUndoCheckout',image : url + '/img/undocheckout.gif'});
			ed.addButton('checkin', {title : 'Checkin', cmd : 'epfwikiCheckin',image : url + '/img/checkin.gif'});
			ed.addButton('save', {title : 'Save', cmd : 'epfwikiSave',image : url + '/img/save.gif'});
			//ed.addButton('cancel', {title : 'save.cancel_desc', cmd : 'mceCancel'});

			ed.onNodeChange.add(t._nodeChange, t);
			ed.addShortcut('ctrl+s', ed.getLang('save.save_desc'), 'epfwikiSave');
		},

		getInfo : function() {
			return {
				longname : 'EPF Wiki',
				author : 'Onno van der Straaten',
				authorurl : 'http://www.eclipse.org/epf',
				infourl : 'http://www.eclipse.org/epf',
				version : tinymce.majorVersion + "." + tinymce.minorVersion
			};
		},

		// Private methods

		_nodeChange : function(ed, cm, n) {
			var ed = this.editor;

			if (ed.getParam('save_enablewhendirty')) {
				cm.setDisabled('save', !ed.isDirty());
				//cm.setDisabled('cancel', !ed.isDirty());
			}
		},

		// Private methods

		_save : function() {
			var ed = this.editor, formObj, os, i, elementId;

			formObj = tinymce.DOM.get(ed.id).form || tinymce.DOM.getParent(ed.id, 'form');

			if (ed.getParam("save_enablewhendirty") && !ed.isDirty())
				return;

			tinyMCE.triggerSave();

			// Use callback instead
			if (os = ed.getParam("save_onsavecallback")) {
				if (ed.execCallback('save_onsavecallback', ed)) {
					ed.startContent = tinymce.trim(ed.getContent({format : 'raw'}));
					ed.nodeChanged();
				}

				return;
			}

			if (formObj) {
				ed.isNotDirty = true;

				if (formObj.onsubmit == null || formObj.onsubmit() != false)
					formObj.submit();

				ed.nodeChanged();
			} else
				ed.windowManager.alert("Error: No form element found.");
		},
		_checkin : function() {
				tinyMCE.activeEditor.execCommand('mceFullScreen');
				var inst = tinyMCE.selectedInstance;
				var ed = this.editor, formObj, os, i, elementId;
				formObj = tinymce.DOM.get(ed.id).form || tinymce.DOM.getParent(ed.id, 'form');
				if (confirm('Save and check-in the current document?')) {
					console.log('formObj.action: '+ formObj.action);
					formObj.action = formObj.action.replace('/pages/save','/pages/checkin'); // EPF-100
					inst.execCommand('epfwikiSave');
				}
				return true;
		},
		_undocheckout : function() {
				var inst = tinyMCE.selectedInstance;
				var ed = this.editor, formObj, os, i, elementId;				
				formObj = tinymce.DOM.get(ed.id).form || tinymce.DOM.getParent(ed.id, 'form');
   				if (confirm('Are you sure to want to undo the checkout? Any changes made to this version will be lost.')) {  
   					formObj.action = formObj.action.replace('/pages/save','/pages/undocheckout'); // EPF-100
  					formObj.submit();
  				 }
				formObj.onsubmit;
				return true;
		}
	});
	// Register plugin
	tinymce.PluginManager.add('epfwiki', tinymce.plugins.EPFWiki);
})();
