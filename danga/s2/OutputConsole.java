package danga.s2;

import java.io.OutputStreamWriter;
import java.io.BufferedWriter;
import java.io.Writer;

public class OutputConsole extends Output {

    BufferedWriter out;

    public OutputConsole () {
        try {
            out = new BufferedWriter(new OutputStreamWriter(System.out, "UTF-8"),
                                     4096);
        } catch (Exception e) {
            System.err.println("ERROR: Java installation doesn't support UTF-8?");
        }
    }
    
    public void write (String s) {
        try {
            out.write(s);
        } catch (Exception e) {
            System.err.println("Error: "+e.toString());
        }
    }

    public void newline () {
        write("\n");
    }

    public void flush () { 
        try { out.flush(); }
        catch (Exception e) {
            System.err.println("UTF-8 output flush failed");
        }
    }
}
