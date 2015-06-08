function epfwiki_includes(){
	var epfwiki_footer = document.createElement("div");
	epfwiki_footer.id="epfwiki_footer";
	epfwiki_footer.innerHTML="<img src='" + backPath + "../../images/busy.gif'></img>";
	document.body.appendChild(epfwiki_footer)
	
	var checkout_text = document.createElement("div");
	checkout_text.id = "checkout_text";
	document.body.insertBefore(checkout_text, document.body.firstChild);

	var spacer = document.createElement("div");
	spacer.id = "spacer";
	document.body.insertBefore(spacer, document.body.firstChild);

	var epfwiki_header = document.createElement("div");
	epfwiki_header.id="epfwiki_header";
	epfwiki_header.innerHTML="<img src='" + backPath + "../../images/busy.gif'></img>";
	document.body.insertBefore(epfwiki_header,document.body.firstChild);

	var page_href = document.location.href;
	var page_id = location.pathname.replace(/\//g, '_').replace(/\./g,'_') + '.js';
	// page_id is to allow the possibility for caching
    var url = backPath + '../../pages/view/'+page_id+'?url='+page_href;
    $.ajax({url: url});
}
$(document).bind("ready", epfwiki_includes)