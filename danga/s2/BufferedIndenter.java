package danga.s2;

// NOTE: wrote this, used it for awhile, then decided not to use it.
//       it works, but it'll probably bit rot.

public class BufferedIndenter extends Indenter
{
    public BufferedIndenter (Indenter i) {
	depth = i.depth;
	tabsize = i.tabsize;
	makeSpaces();
	o = new OutputStringBuffer();
    }

    public void writeTo (Indenter i) {
	OutputStringBuffer osb = (OutputStringBuffer) o;
	osb.writeTo(i);
    }
}
