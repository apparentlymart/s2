package danga.s2;

/* if I knew java.io.* more, I'd probably not write this.  */

public class OutputConsole extends Output {
    
    public void write (String s) {
	System.out.print(s);
    }

    public void newline () {
	System.out.println("");
    }
}
