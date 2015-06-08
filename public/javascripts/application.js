// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function showTab(tab)
{
	$('.portal-tab').hide();
	$('#' + tab).show();	
};

// http://www.appelsiini.net/projects/jeditable
$(document).ready(function() {
	// will produce error if ... 
    //$('.edit').editable('http://www.example.com/save.php', {
    //    indicator : 'Saving...',
    //    tooltip   : 'Click to edit...'
    //});
	
	

    $('.edit-area').each(function(index) {
    	//console.log(index + ': ' + $(this).text());
    	//console.log('class-name: ' + $(this).attr('data-class-name'));
    	//console.log('url: ' + $(this).attr('data-url'));
    	//console.log('id: ' + $(this).attr('id'));
        $(this).editable($(this).attr('id'), { 
            type      : 'textarea',
            cancel    : 'Cancel',
            submit    : 'OK',
            indicator : '<img src="/images/progress.gif">',
            tooltip   : 'Click to edit...',
            submitdata: {class_name: $(this).attr('data-class-name')}
        });
    	
    });

    
});


