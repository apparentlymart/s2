package danga.s2;

public class Indenter
{
    int depth = 0;
    int tabsize = 4;
    Output o;

    String spaces;

    public Indenter () {
	o = new OutputConsole();
    }

    public Indenter (Output o, int tabsize) {
	this.tabsize = tabsize;
	this.o = o;
	makeSpaces();
    }

    public void write (String s) { o.write(s); }
    public void writeln (String s) { o.writeln(s); }

    public void tabwrite (String s) { doTab(); o.write(s); }
    public void tabwriteln (String s) { doTab(); o.writeln(s); }

    public void newline () { o.newline(); }

    public void tabIn () { depth++; makeSpaces(); }
    public void tabOut () { depth--; makeSpaces(); }

    protected void makeSpaces () {
	int tsize = depth * tabsize;
	char[] spaces = new char[tsize];
	for (int i=0; i<tsize; i++) {
	    spaces[i] = ' ';
	}
	this.spaces = new String(spaces);
    }

    public void doTab () {
	o.write(spaces);
    }


}
