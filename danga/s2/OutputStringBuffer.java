package danga.s2;

/* if I knew java.io.* more, I'd probably not write this.  */

public class OutputStringBuffer extends Output {
    
    StringBuffer sb;
    public OutputStringBuffer () {
	sb = new StringBuffer();
    }

    public void write (String s) {
	if (s == null) {
	    System.err.println("\n write s==null");
	}
	sb.append(s);
    }

    public void newline () {
	sb.append('\n');
    }

    public void writeTo (Indenter i) {
	i.write(sb.toString());
    }
}
