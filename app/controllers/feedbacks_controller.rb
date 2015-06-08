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

# Feedback is created in the portal by authenticated and anonymous users, 
# see OtherController.feedback. This controller together with SitesController
# is used to manage feedback, see SitesController.feedback

class FeedbacksController < ApplicationController

  layout 'management'
  
  before_filter :authenticate_cadmin
  
  protect_from_forgery :except => [:destroy] # workaround for ActionController::InvalidAuthenticityToken

  def edit
    @feedback = Feedback.find(params[:id])
  end
  
  def update
    @feedback = Feedback.find(params[:id])
    if @feedback.update_attributes(params[:feedback])
      flash[:notice] = 'Feedback was successfully updated.'
      redirect_to @feedback.request_referer
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    Feedback.find(params[:id]).destroy
    redirect_to :back
  end
  
end
