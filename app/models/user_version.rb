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

class UserVersion < Version

  def path
    return self.wiki.path + '/' + self.rel_path
  end
    
  def html=(h)
    logger.debug("Saving HTML to #{self.path}")
    f = File.new(self.path, "w")
    f.puts(h)
    f.close
    # works on the file, we are using tidy lib
    #self.tidy if self.user_version? TODO remove 
    h = self.html.gsub(Page::SHIM_TAG_PATTERN, Page::SHIM_TAG)
    f = File.new(self.path, "w")
    f.puts(h)
    f.close
  end
  
end