# Copyright (c) 2006-2013 OnKnows.coms
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation

class UmaType < ActiveRecord::Base
  has_many :pages 
end