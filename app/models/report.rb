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

class Report
  attr_accessor :report_type, :users, :site, :starttime, :endtime, :runtime, :subject, :items

  def initialize(report_type, site = nil, runtime = Time.now)
    @report_type = report_type
    @site = site
    @runtime = runtime
    case report_type
    when 'D' # daily
      @starttime = (runtime - 1.day).at_beginning_of_day
      @endtime = runtime.at_beginning_of_day
      if @site
        @users = Notification.find_all_users(@site, 'Daily')
      else
        @users = User.find_all_by_notify_daily(1)
      end
      subject_text = 'Daily'
    when 'W' # weekly
      @starttime = (runtime - 1.week).at_beginning_of_week
      @endtime = runtime.at_beginning_of_week
      if @site
        @users = Notification.find_all_users(@site, 'Weekly')
      else
        @users = User.find_all_by_notify_weekly(1)
      end
      subject_text = 'Weekly'
    when 'M' # monthly
      @starttime = (runtime - 1.month).at_beginning_of_month
      @endtime = runtime.at_beginning_of_month
      if @site
        @users = Notification.find_all_users(@site, 'Monthly')
      else
        @users = User.find_all_by_notify_monthly(1)
      end
      subject_text = 'Monthly'
    else
      raise 'Report type is required'
    end
    subject_text = "#{@site.title} " + subject_text if @site
    @subject = "[#{ENV['EPFWIKI_APP_NAME']}] #{subject_text} Summary"
    @items = Site.changed_items(self)
  end
end