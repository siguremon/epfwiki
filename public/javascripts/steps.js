//------------------------------------------------------------------------------
// Copyright (c) 2005, 2006 IBM Corporation and others.
// All rights reserved. This program and the accompanying materials
// are made available under the terms of the Eclipse Public License v1.0
// which accompanies this distribution, and is available at
// http://www.eclipse.org/legal/epl-v10.html
// 
// Contributors:
// IBM Corporation - initial implementation
//------------------------------------------------------------------------------

var collapseStepsByDefault = true;
var stepImgBackPath = '../../';
var expandAllText = "Expand All Steps";
var collapseAllText = "Collapse All Steps";
var firstStepSection;

// Creates the collapsible step section links.
function createStepLinks(tagName, classSelector) {
	if (document.getElementsByTagName) {
		var elements = document.getElementsByTagName(tagName);
		if (elements.length == 0) return;
		var stepElements = new Array(elements.length);
		var totalLinks = 0;
		for (var i = 0; i < elements.length; i++) {
			var element = elements[i];
			if (element.className == classSelector) {
				stepElements[totalLinks++] = element;
			}
		}
		if (totalLinks == 0) return;
		stepElements.length = totalLinks;
		stepCollapseDivs = new Array(totalLinks);
		stepCollapseLinks = new Array(totalLinks);
		firstStepSection = stepElements[0];
		for (var i = 0; i < stepElements.length; i++) {
			var element = stepElements[i];
			var siblingContainer;
			if (document.createElement && (siblingContainer = document.createElement('div')) && siblingContainer.style) {
				var nextSibling = element.nextSibling;
				element.parentNode.insertBefore(siblingContainer, nextSibling);
				var nextElement = stepElements[i + 1];
				while (nextSibling != nextElement && nextSibling != null) {
					var toMove = nextSibling;
					nextSibling = nextSibling.nextSibling;
					siblingContainer.appendChild(toMove);
				}
				if (collapseStepsByDefault) {
    				siblingContainer.style.display = 'none';
    			}
    			siblingContainer.style.display = 'none';
    			stepCollapseDivs[i] = siblingContainer;
    			createCollapsibleStepSection(element, siblingContainer, i);
			}
			else {
				return;
			}
		}
		createExpandCollapseAllStepsLinks(stepElements[0]);
	}
}

// Creates a collapsible step section.
function createCollapsibleStepSection(element, siblingContainer, index) {
	if (document.createElement) {
		var span = document.createElement('span');
		var link = document.createElement('a');
		link.collapseDiv = siblingContainer;
		link.href = '#';
		var image = document.createElement('img');
		if (collapseStepsByDefault) {
			image.src = expandImage;
		}
		else {
			image.src = collapseImage;
		}
		image.width = '17';
		image.height = '15';
		image.border = '0';
		image.align = 'absmiddle';
		link.appendChild(image);
		link.onclick = expandCollapseStepSection;
		stepCollapseLinks[index] = link;
		span.appendChild(link);
		element.insertBefore(span, element.firstChild);
		element.appendChild(document.createTextNode(String.fromCharCode(160)));
		element.appendChild(document.createTextNode(String.fromCharCode(160)));
	}
}

// Expands or collapses a step section based on the received event.
function expandCollapseStepSection(evt) {
	if (this.collapseDiv.style.display == '') {
		this.parentNode.parentNode.nextSibling.style.display = 'none';
		this.firstChild.src = expandImage;
	}
	else {
		this.parentNode.parentNode.nextSibling.style.display = '';
		this.firstChild.src = collapseImage;
	}
	if (evt && evt.preventDefault) {
		evt.preventDefault();
	}
	return false;
}

// Creates the Expand All and Collapse All Steps links.
function createExpandCollapseAllStepsLinks(firstElement) {
	var div;
	if (document.createElement && (div = document.createElement('div'))) {
		div.className = 'expandCollapseLink';
		div.align = 'right';		
		var image = document.createElement('img');
		image.src = expandAllImage;
		image.width = '16';
		image.height = '16';
		image.border = '0';
		image.align = 'absmiddle';
		var link = document.createElement('a');
		link.className = 'expandCollapseLink';
		link.href = '#';
		link.appendChild(image);
		link.onclick = expandAllSteps;
		var span = document.createElement('span');
		span.className = 'expandCollapseText';
		span.appendChild(document.createTextNode(expandAllText));
		link.appendChild(span);
		div.appendChild(link);
		div.appendChild(document.createTextNode(String.fromCharCode(160)));
		
		image = document.createElement('img');
		image.src = collapseAllImage;
		image.width = '16';
		image.height = '16';
		image.border = '0';
		image.align = 'absmiddle';
		link = document.createElement('a');
		link.className = 'expandCollapseLink';
		link.href = '#';
		link.appendChild(image);
		link.onclick = collapseAllSteps;
		span = document.createElement('span');
		span.className = 'expandCollapseText';
		span.appendChild(document.createTextNode(collapseAllText));
		link.appendChild(span);
		div.appendChild(link);
		
		if (firstStepSection) {
			firstStepSection.parentNode.insertBefore(div, firstStepSection);
		}
	}
}

// Expands all steps.
function expandAllSteps(evt) {
	 for (var i = 0; i < stepCollapseDivs.length; i++) {
	 	stepCollapseDivs[i].style.display = '';
	 	stepCollapseLinks[i].firstChild.src = collapseImage;
	 }
	 if (evt && evt.preventDefault) {
	 	evt.preventDefault();
	 }
	 return false;
}

// Collapses all steps.
function collapseAllSteps(evt) {
	for (var i = 0; i < stepCollapseDivs.length; i++) {
		stepCollapseDivs[i].style.display = 'none';
		stepCollapseLinks[i].firstChild.src = expandImage;
	}
	if (evt && evt.preventDefault) {
		evt.preventDefault();
	}
	return false;
}
