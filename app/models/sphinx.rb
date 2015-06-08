# Copyright (c) 2013 OnKnows.com
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation
class Sphinx

  # Start Sphinx, if enabled and not started
  def self.start
    if Rails.application.config.sphinxsearch
      if File.exists? pid_file
        if File.read(pid_file).to_i == 0
          log("WARNING: pid file exists but is empty. Stop any other running instances first")
          ts.start
        else
          log("Sphinx already started, pid: #{File.read(pid_file)}")
        end
      else
        ts.start
        log("Sphinx started, pid: #{File.read(pid_file)}")
      end

    else
      log("Don't start Sphinx. Not enabled.")
    end
  end

  # Stop Sphinx, if enabled and not stopped
  def self.stop
    if Rails.application.config.sphinxsearch
      if File.exists? pid_file
        if File.read(pid_file).to_i == 0
          log("WARNING Empty pid file, can't stop.")
        else        
          log("Stopping Sphinx, pid: #{File.read(pid_file)}")  
          ts.stop
        end
      else
        log("Sphinx not started")
      end
    else
      log("Don't stop Sphinx. Not enabled.")
    end
  end

  def self.status
    if Rails.application.config.sphinxsearch
      if File.exists? pid_file
        if File.read(pid_file).to_i == 0
          s = "WARNING Empty pid file."
        else        
          s = "Sphing is running, pid: #{File.read(pid_file)}"
        end
      else
        s = "Sphinx not started"
      end
    else
      s = "Sphinx disabled"
    end
    log(s)
    s
  end

  # Create Sphinx index
  def self.index
      ts.start # Start Sphinx, if enabled and not started
      ts.index
  end

  # Create Sphinx index
  def self.configure
      ts.configure
  end

  def self.pid_file
    ThinkingSphinx::Configuration.instance.searchd.pid_file
  end

  def self.ts
    ThinkingSphinx::RakeInterface.new
  end
  
  def self.log(msg)
    Rails.logger.info(msg)
    puts msg
  end

end