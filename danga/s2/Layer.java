package danga.s2;

import java.util.LinkedList;
import java.util.ListIterator;
import java.util.Hashtable;
import java.util.Enumeration;

public class Layer
{
    String type;
    String declaredType;
    LinkedList nodes = new LinkedList();
    Hashtable layerinfo = new Hashtable();
    
    public Layer (Tokenizer toker, String type) throws Exception 
    {
	this.type = type;

	Node n;
	Token t;

	while ((t=toker.peek()) != null) {
	    if (NodeUnnecessary.canStart(toker)) {
		nodes.add(NodeUnnecessary.parse(toker));
		continue;
	    }

	    if (NodeLayerInfo.canStart(toker)) {
		NodeLayerInfo nli = (NodeLayerInfo) NodeLayerInfo.parse(toker);
		nodes.add(nli);
		
		// Remember the 'type' layerinfo value for checking later:
		if (nli.getKey().equals("type")) {
		    declaredType = nli.getValue();
		}
		continue;
	    }

	    if (NodeSet.canStart(toker)) {
		nodes.add(NodeSet.parse(toker));
		continue;
	    }
		
	    if (NodeProperty.canStart(toker)) {
		nodes.add(NodeProperty.parse(toker));
		continue;
	    }

	    if (NodeFunction.canStart(toker)) {
		nodes.add(NodeFunction.parse(toker, false));
		continue;
	    }
		
	    if (NodeClass.canStart(toker)) {
		nodes.add(NodeClass.parse(toker));
		continue;
	    }

	    throw new Exception("Unknown token encountered while parsing layer: "+
				t.toString());
	    
	}
    }

    public void setLayerInfo (String key, String val) {
	layerinfo.put(key, val);
    }
    public String getLayerInfo (String key) {
	return (String) layerinfo.get(key);
    }
    public Enumeration getLayerInfoKeys () { return layerinfo.keys();  }
    public String getType () { return type; }
    public String getDeclaredType () { return declaredType; }
    public void setType (String newtype) { type = newtype; }
    public String toString () { return type;  }
    public LinkedList getNodes() { return nodes; }
    public boolean isCoreOrLayout () {
	return (type.equals("core") || type.equals("layout"));
    }

}
