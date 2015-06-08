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

require 'test_helper'

class EpfcLibraryTest < ActiveSupport::TestCase
  
  # running tests on Windows requires UnxUtils, please see the README_FOR_APP.
  # This test causes a runtime error if unzip is not installed
  test "Unzip" do
    cmd = IO.popen('unzip -version', "w+")
    cmd.close_write
  end
end
