var filters = ['site','type'];

// build url for current selection
// pass the element that triggers the request, item with class check-list-item or pagination link 
function buildUrl(elem) {
	var criteria = new Array();
	var page; 
	txt = $('#btn-group-search input').val();
	if (txt != '') {
		criteria.push('text=' + txt);
	}
	if (elem.attr('class') == 'check-list-item' || elem.attr('type') == 'text' || elem.attr('type') == 'button') { // text is search box
		//criteria.push('page=' + $('.pagination .current').text()); 
	} else {
		//console.log('buildUrl was triggered by click on pagination-link');
		page = elem.attr('href').split('page=').reverse()[0];
		if (page.indexOf('&') != -1) {
			page = page.split('&')[0];
		}
		criteria.push('page=' + page);
	}
	//console.dir(criteria);
    for(var i1 = 0; i1 < filters.length; i1++) {
    	var btn_group = $('#btn-group-' + filters[i1]);
    	btn_group.find( "input:checked").each(function(index) {
    		var id = $(this).attr('value');
    		var data_item = $(this).attr('data-param');
    		criteria.push(data_item + '[]=' + id);
    	}); 
    }
	var newUrl = $.param.fragment('#' + criteria.join('&'));
	//console.log('buildUrl: ' + newUrl);
	return newUrl;
}

// for each filter, update filter fields so they match criteria
// Example of a filter field is <input type="checkbox" tabindex="-1" value="2" data-title="Templates" data-param="wiki">
// TODO all uncheck
function checkFilters(url) {
	//console.log('checkFilters for url ' + url);
	var criteria = $.deparam.querystring(url);
    for(var i1 = 0; i1 < filters.length; i1++)
	{
    	if(typeof criteria[filters[i1]] != 'undefined') {
	    	var filter_values = criteria[filters[i1]];
	    	for(var i2 = 0; i2 < filter_values.length; i2++)
			{
	    		var slctr = "input[value='" + filter_values[i2] + "'][data-param='" + filters[i1] + "']";
	    		//console.log('Check filter element: ' + slctr);
	    		$(slctr).prop('checked', true);
			} // array filter_values
		} // defined
	} // array filters
    //console.dir(criteria);
    if(typeof criteria['text'] != 'undefined') {
    	$('.search-box').val(criteria['text']);
    }
} // function checkFilters

// Update label of filter buttons so they show some of selected criteria
function updateFilterLabels(url) {
	//console.log('updateFilterLabels for url ' + url);
	var criteria = $.deparam.querystring(url);
    for(var i1 = 0; i1 < filters.length; i1++)
	{
    	var btn_group = $('#btn-group-' + filters[i1]);
    	if (typeof btn_group[0] != 'undefined') { // btn_group is null when site filter is not displayed
        	if(typeof criteria[filters[i1]] != 'undefined') {
        		//console.log('    filter: ' + filters[i1]);
    	    	var filter_values = criteria[filters[i1]];
    	    	if (typeof(filter_values) == 'string') {
    	    		filter_values = new Array(filter_values);
    	    	}
        		//console.dir(filter_values);
    	    	var filter_labels = new Array();
    	    	for(var i2 = 0; i2 < filter_values.length; i2++)
    			{
    	    		var slctr = "input[value='" + filter_values[i2] + "'][data-param='" + filters[i1] + "']";
    	    		//console.log('    Select element: ' + slctr);
    	    		filter_labels.push($(slctr).attr('data-title'));
    			} // array filter_values
    	    	//console.dir(filter_labels);
    	    	btn_group.find('button').attr('data-original-title',filters[i1] + ': ' + filter_labels.join(', ')); // used for tooltip
        		var spn = btn_group.find('button').find('span')[0].outerHTML + filter_labels.join(', ').substring(0,18);
        		btn_group.find('button').find('.criteria-wrap').html(spn + '...' + '<span class="caret"></caret>');
    		} // defined
        	else {
    			var spn = btn_group.find('button').find('span')[0].outerHTML + 'All';
    			btn_group.find('button').find('.criteria-wrap').html(spn);
        	} // undefined
    	} // btn_group != null
	} // array filters
} // function updateFilterLabels

// Pagination links must disabled on page load and on each page link request
function disablePaginationLinks() {
	$(".pagination a").click(function() {
		fragment = buildUrl($(this));
		$.bbq.pushState('#' + fragment,2);
		return false;
	});
}

$( document ).ready(function() {
	
	$('.btn-title').tooltip();
	
	// Search when user presses enter in search box
	$('#btn-group-search input').on('keypress', function (event) {
        if(event.which == '13'){
    		var newUrl = buildUrl($(this));
    		//updateFilterLabels(newUrl);
    		$.bbq.pushState('#' + newUrl,2);
        }
	});
	
	// Search when user presses Go button
	$('#btn-group-search button').click(function(e){
		var newUrl = buildUrl($(this));
		//updateFilterLabels(newUrl);
		$.bbq.pushState('#' + newUrl,2);
	});
	
	disablePaginationLinks(); // TODO rename ajaxPaginationLinks
	
	$('.dropdown-menu').click(function(e) {//alert('stopProp');
		//window.console && console.log('.dropdown-menu click');
		e.stopPropagation();
	});
	
	$('.check-a-item').click(function(e) {
	});
	
	$('.check-list-item').click(function(e) {//alert('stopProp');
		//var href = $(this).attr( "href" );
		// Push this URL "state" onto the history hash.
		//$.bbq.pushState({ url: href });
		var id = $(this).find("input").attr('value');
		var btn_group = $(this).parents('.btn-group');
		if ($(this).find("input").is(':checked')) {
			//console.log('deselect');
			$(this).find("input").attr('checked', false);
			//http://stackoverflow.com/questions/426258/how-do-i-check-a-checkbox-with-jquery
		} else {
			//console.log('select');
			//$(this).find("input").attr('checked', false); // Whoe ha ha ha dit werkt niet zie http://stackoverflow.com/questions/18097875/jquery-is-changing-checkbox-value-but-the-checkbox-is-not-displaying-as-checked
			$(this).find("input").prop('checked', true);
		};
		var criteria = new Array(); // use for creating url
		$(this).parent().parent().find( "input:checked").each(function(index) {
			var id = $(this).attr('value');
			var data_item = $(this).attr('data-param');
			criteria.push(data_item + '=' + id);
			//console.log('Add to criteria: '+ data_item + '=' + id);
		}); 
		//console.log('Add to url ' + criteria.join('&'));
		var newUrl = buildUrl($(this));
		//console.log('newUrl: ' + newUrl );
		//updateFilterLabels(newUrl);
		
		$.bbq.pushState('#' + newUrl,2);
		e.stopPropagation();
	});
	
	$(".filter-box").on('input', function(e) {
		// todo show all if empty
		var v1 = $(this).val();
		if (v1 == "") {
			//console.log('geen filter, toon alles');
			$(this).parent().parent().find(".check-list-item,.check-list-item-group,.divider").show();
		} else
		{
			//console.log('v1: ' + v1);

			$(this).parent().parent().find(".check-list-item,.check-list-item-group,.divider").hide(); // alles hide
			$(this).parent().parent().find(".check-list-item").each(function(index) {
				//return index % 3 === 2;
				v2 = $(this).find('input').attr('data-title');
				//console.log('v2: ' + v2);
				if (v2.toLowerCase().indexOf(v1.toLowerCase()) != -1) {
					$(this).show();
				};
			}); 
		};

	});

	  // Bind a callback that executes when document.location.hash changes.
	  $(window).bind( "hashchange", function(e) {
		  //console.log('hashchange');
	    var fragment = $.param($.bbq.getState());
	    //console.log('    fragment: ' + fragment);
	    var criteria;
	    
	    var href = window.location.href;
	    var ajax_url = href.replace('#'+ $.param.fragment(href),''); // e.g. http://localhost:3000/search
	    var ajax_url = href.split('#')[0];
	    var pattern = /\/\/.*?\/(.*?)\/\d*\/search/;
	    var cookie_name = 'epfw_search_fragment';
	    m = href.match(pattern);
	    if (m != null) {
	    	cookie_name = cookie_name + '_' + m[1]; // e.g. 'openup' if url is something like http://localhost:3000/openup/671/search
	    } 
	    //console.log('    cookie_name:' + cookie_name);
	    if (fragment != '') {
	    	ajax_url = ajax_url + '?' + fragment; // e.g. http://localhost:3000/search#text=bitcoin | "test data"&site[]=4	
		    $.getScript(ajax_url);
		    updateFilterLabels(ajax_url);
		    checkFilters(ajax_url);
		    $.cookie(cookie_name, fragment, { expires: 90, path: '/' }); // remove path to make search specific per page
	    } else {
	    	if ($.cookie(cookie_name) != null) {
		    	fragment = decodeURIComponent($.cookie(cookie_name));
		    	$.bbq.pushState('#' + fragment,2);
	    	} else {
	    		// no state to push
	    	};
	    };
	    //console.log('disablePaginationLinks, ajax_url: ' + ajax_url);
	    
	  }); // end hashchange

	  // Since the event is only triggered when the hash changes, we need
	  // to trigger the event now, to handle the hash the page may have
	  // loaded with.
	 $(window).trigger( "hashchange" );
});
