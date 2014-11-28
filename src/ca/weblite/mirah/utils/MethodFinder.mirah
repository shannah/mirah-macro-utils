
package ca.weblite.mirah.utils
import mirah.lang.ast.*

import java.util.ArrayList

class MethodFinder < NodeScanner
  def initialize
    @results = ArrayList.new
  end
  
  def enterMethodDefinition(mdef:MethodDefinition,arg:Object) : boolean
    @results.add mdef
    super
  end
  
  
  
  def results:MethodDefinition[]
    @results.toArray(MethodDefinition[0])
  end
end

class ConstructorFinder < NodeScanner
  def initialize
    @results = ArrayList.new
  end
  
  def enterConstructorDefinition(mdef:ConstructorDefinition,arg:Object) : boolean
    @results.add mdef
    super
  end
  
  
  
  def results:ConstructorDefinition[]
    @results.toArray(ConstructorDefinition[0])
  end
end

class ElemAssignFinder < NodeScanner
  def initialize
    @results = ArrayList.new
    
  end
  
  def enterElemAssign(node, arg)
    @results.add node
    super(node, arg)
  end
  
  def results:ElemAssign[]
    @results.toArray(ElemAssign[0])
  end
  
end

class AttrAssignFinder < NodeScanner
  def initialize
    @results = ArrayList.new
    
  end
  
  def enterAttrAssign(node, arg)
    @results.add node
    super(node, arg)
  end
  
  def results:AttrAssign[]
    @results.toArray(AttrAssign[0])
  end
  
end

