package danga.s2;

public abstract class Backend {
    
    Layer layer;

    public abstract void output (Output o);

    public static String quoteString (String s)
    {
	int len = s.length();
	StringBuffer sb = new StringBuffer(len + 20);
	sb.append("\"");
	sb.append(quoteStringInner(s));
	sb.append("\"");
	return sb.toString();
    }

    public static String quoteStringInner (String s)
    {
	int len = s.length();
	StringBuffer sb = new StringBuffer(len + 20);
	for (int i=0; i<len; i++) {
	    char c = s.charAt(i);
	    if (c=='\\' || c=='$' || c=='"') 
		sb.append('\\');
	    sb.append(c);
	}
	return sb.toString();
    }

};
