# see http://
atom_feed :language => 'en-US' do |feed|
	
	if @wiki
		t = @wiki.title
	else
		t = ENV['EPFWIKI_APP_NAME']
	end
	
	feed.title t
	feed.updated @updated
	feed.description h("News, changes, comments, baseline updates in #{t}")
  
  @records.each do |r|
  	logger.debug("r: #{r.inspect}")

    if r.class == Update
	    w = r.wiki
	    feed.entry( r, :url => w.url ) do |e|
	      #e.url
	      e.updated(r.created_on.gmtime.strftime("%Y-%m-%dT%H:%M:%SZ")) # the strftime is needed to work with Google Reader.
	      e.author do |author|
	        author.name @cadmin.name
	      end
	      if r.first_update?
	        e.title "#{w.title} created!"
	        e.content "A new Wiki with title \"#{w.title}\" was created"
	      else
	        e.title "#{w.title} updated!"
	        e.content "Wiki #{w.title} was updated with baseline #{w.baseline_process.title}"
	      end
		end
    end

    if r.class == Upload
    	feed.entry( r, :url => r.url ) do |e|
			#e.link r.url
			#e.url r.url
			e.title "#{r.user.name} uploaded #{r.filename}" 
			e.content r.description, :type => "html"
			e.updated(r.created_on.gmtime.strftime("%Y-%m-%dT%H:%M:%SZ"))
			e.author do |author|
			  author.name r.user.name
			end
      	end
    end

	if r.class == UserVersion
    	feed.entry( r, :url => r.page.url ) do |e|
			#e.url r.page.url
			e.title "#{r.user.name} changed #{r.page.presentation_name}" 
			e.content r.note
			e.updated(r.created_on.gmtime.strftime("%Y-%m-%dT%H:%M:%SZ"))
			e.author do |author|
			  author.name r.user.name
			end
		end
	end

	if r.class == Comment
		feed.entry( r, :url => r.page.url ) do |e|	
			#e.url r.page.url
			e.title "#{r.user.name} discussed '#{r.page.presentation_name}'"
			e.content r.text, :type => "html"
			 e.updated(r.created_on.gmtime.strftime("%Y-%m-%dT%H:%M:%SZ"))
			e.author do |author|
				author.name r.user.name
			end
		end
	end

  end # @records
end # feed




