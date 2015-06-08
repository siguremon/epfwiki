# Copyright (c) 2006-2013 OnKnows.com, Logica, 2008 IBM, and others
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation
#* Ricardo Balduino:: additions for feed generation (practices and UMA types)

class ReviewController < ApplicationController
  
  before_filter :authenticate_admin
  before_filter :find_record
  
  protect_from_forgery :except => [:note,:toggle_done, :assign] 
  
  # Action #toggle_done toggles the <tt>done</tt> column. 
  def toggle_done
    if @record.reviewer.nil? || @record.reviewer == session_user || cadmin?
      if @record.done == 'Y'
        @record.update_attributes(:done => 'N')
      else
        @record.update_attributes(:done => 'Y')
      end
      @html = "<%= link_to_done_toggle(@record) %>"
    else
      @html = "<script language=\"JavaScript\">alert('To change the done flag you need to be the reviewer or " + 
        "the central administrator (#{User.find_central_admin.name})!')</script><%= link_to_done_toggle(@record) %>"
    end
    @div_id = "#{params['class_name']}#{params['id']}_done_toggle"
    respond_to do |format|
      format.js 
    end
  end
  
  #Action #review assigns current User as the reviewer
  def assign
    @html = "<%= link_to_reviewer(@record) %>"
    if @record.reviewer.nil?
        @record.update_attributes(:reviewer => session_user)
    elsif @record.reviewer == session_user
        @record.update_attributes(:reviewer => nil)
    elsif cadmin?
        @record.update_attributes(:reviewer => session_user)
    elsif !@record.reviewer.nil? && !cadmin?
        @html = "<script language=\"JavaScript\">alert('Only the central administrator (#{User.find_central_admin.name}) can change or clear the reviewer!')</script><%= link_to_reviewer(@record) %>"
    end
    respond_to do |format|
      format.js 
    end
  end
  
  # Action #review_note updates the review note
  def note
    if @record.reviewer.nil? || @record.reviewer == session_user || cadmin?
      @js_msg = ''
      @record.review_note = params[:value]
      @record.save!
    else
      @js_msg = "<script language=\"JavaScript\">alert('Only the central administrator (#{User.find_central_admin.name}) or the reviewer can update the review note!')</script>"
    end
    @record.reload
    render :layout => false, :inline => "<%= @record.review_note %>" + @js_msg
  end
  
  #######
  private
  #######
  
  def find_record
    logger.debug("Find record using params: #{params.inspect}")
    case params['class_name'] 
    when 'Version' then @record = Version.find(params[:id])
    when 'UserVersion' then @record = Version.find(params[:id])
    when 'BaselineProcessProcessVersion' then @record = Version.find(params[:id])
    when 'Upload' then @record = Upload.find(params[:id])
    when 'Comment' then  @record = Comment.find(params[:id])  
    else @record = DaText.find(params[:id])
    end
  end
end
