package danga.s2;

/* if I knew java.io.* more, I'd probably not write this.  */

public abstract class Output {
    
    public abstract void write (String s);
    public void write (int i) {
        write(new Integer(i).toString());
    }
    public void writeln (int i) {
        write(new Integer(i).toString());
        newline();
    }
    public void writeln (String s) {
	write(s);
	newline();
    }
    public abstract void newline ();
}
